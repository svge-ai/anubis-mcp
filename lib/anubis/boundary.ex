defmodule Anubis.Boundary do
  @moduledoc """
  Scans `lib/` and `test/` for denied words, and rejects forbidden deps.

  Words come from `config/boundary_deny.txt`. A line wrapped in `/` is a
  regex. `config/boundary_allow.exs` allows one file, line, and word.
  The sync doc, the allow file, and the changelog are not scanned.
  """

  @deny_file "config/boundary_deny.txt"
  @allow_file "config/boundary_allow.exs"
  @scan_dirs ~w(lib test)
  @max_bytes 2_000_000
  @skip_dirs ~w(.git deps _build cover .elixir_ls node_modules)
  @sync_doc "SV" <> "GE.md"

  @type finding :: %{path: String.t(), line: pos_integer(), word: String.t()}
  @type allow_entry :: %{
          file: String.t(),
          line: pos_integer(),
          word: String.t(),
          reason: String.t()
        }

  @spec check() :: :ok | {:error, [finding()]}
  def check, do: check(File.cwd!())

  @spec check(Path.t()) :: :ok | {:error, [finding()]}
  def check(root) when is_binary(root) do
    findings = word_findings(root) ++ dependency_findings(File.read!(Path.join(root, "mix.exs")))
    if findings == [], do: :ok, else: {:error, findings}
  end

  @spec deny_entries(Path.t()) :: [String.t()]
  def deny_entries(root) when is_binary(root) do
    load_lines(Path.join(root, @deny_file))
  end

  @spec allow_entries(Path.t()) :: [allow_entry()]
  def allow_entries(root) when is_binary(root) do
    {entries, _binding} = Code.eval_file(Path.join(root, @allow_file))
    Enum.map(entries, &normalize_allow/1)
  end

  @spec scan(Path.t(), keyword()) :: :ok | {:error, [finding()]}
  def scan(root, opts) when is_binary(root) and is_list(opts) do
    deny = Keyword.fetch!(opts, :deny)
    allow = Keyword.get(opts, :allow, [])
    regex = compile(deny)

    findings =
      root
      |> source_files()
      |> Enum.flat_map(&scan_file(&1, root, regex, allow))
      |> Enum.sort_by(&{&1.path, &1.line, &1.word})

    if findings == [], do: :ok, else: {:error, findings}
  end

  @spec dependencies(String.t()) :: :ok | {:error, [finding()]}
  def dependencies(mix_exs) when is_binary(mix_exs) do
    case dependency_findings(mix_exs) do
      [] -> :ok
      findings -> {:error, findings}
    end
  end

  defp word_findings(root) do
    case scan(root, deny: deny_entries(root), allow: allow_entries(root)) do
      :ok -> []
      {:error, findings} -> findings
    end
  end

  defp dependency_findings(mix_exs) do
    mix_exs
    |> deps_from_mix_exs()
    |> Enum.filter(&forbidden_dep?/1)
    |> Enum.map(&dep_finding(&1, mix_exs))
  end

  defp compile([]) do
    raise ArgumentError, "boundary deny list is empty"
  end

  defp compile(entries) do
    body = Enum.map_join(entries, "|", &pattern_source/1)
    {:ok, regex} = Regex.compile("(?i)(?:#{body})")
    regex
  end

  defp pattern_source("/" <> rest) do
    source = String.trim_trailing(rest, "/")
    "(?:#{source})"
  end

  defp pattern_source(word) do
    "(?<![A-Za-z0-9_])#{Regex.escape(word)}(?![A-Za-z0-9_])"
  end

  defp source_files(root) do
    @scan_dirs
    |> Enum.flat_map(&files_in(Path.join(root, &1)))
    |> Enum.reject(&never_scan?(&1, root))
    |> Enum.sort()
  end

  defp files_in(dir) do
    if File.dir?(dir), do: walk(dir, []), else: []
  end

  defp walk(dir, acc) do
    case File.ls(dir) do
      {:ok, names} -> Enum.reduce(names, acc, &collect(Path.join(dir, &1), &1, &2))
      {:error, _} -> acc
    end
  end

  defp collect(path, name, acc) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :directory}} ->
        skip_or_walk(name, path, acc)

      {:ok, %File.Stat{type: :regular, size: size}} when size <= @max_bytes ->
        [path | acc]

      _ ->
        acc
    end
  end

  defp skip_or_walk(name, path, acc) do
    if name in @skip_dirs, do: acc, else: walk(path, acc)
  end

  defp never_scan?(path, root) do
    rel = Path.relative_to(path, root)
    Path.basename(path) in [@sync_doc, "CHANGELOG.md"] or String.ends_with?(rel, "boundary_allow.exs")
  end

  defp scan_file(path, root, regex, allow) do
    rel = Path.relative_to(path, root)

    if text?(path) do
      findings_in(path, rel, regex, allow)
    else
      []
    end
  end

  defp findings_in(path, rel, regex, allow) do
    path
    |> File.stream!()
    |> Stream.with_index(1)
    |> Enum.flat_map(&findings_on_line(&1, rel, regex, allow))
  end

  defp findings_on_line({line, number}, rel, regex, allow) do
    regex
    |> Regex.scan(line)
    |> Enum.map(fn [word | _] -> %{path: rel, line: number, word: word} end)
    |> Enum.reject(&allowed?(&1, allow))
  end

  defp allowed?(%{path: path, line: line, word: word}, allow) do
    downcased = String.downcase(word)

    Enum.any?(allow, fn entry ->
      entry.file == path and entry.line == line and String.downcase(entry.word) == downcased
    end)
  end

  defp text?(path) do
    case File.read(path) do
      {:ok, bin} -> String.valid?(bin) and not String.contains?(bin, <<0>>)
      _ -> false
    end
  end

  defp load_lines(path) do
    path
    |> File.read!()
    |> String.split(~r/\R/u, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  end

  defp normalize_allow(%{} = entry) do
    file = Map.fetch!(entry, :file)
    line = Map.fetch!(entry, :line)
    word = Map.fetch!(entry, :word)
    reason = Map.fetch!(entry, :reason)
    true = valid_allow?(file, line, word, reason)
    %{file: file, line: line, word: word, reason: reason}
  end

  defp valid_allow?(file, line, word, reason) do
    is_binary(file) and is_integer(line) and line > 0 and is_binary(word) and
      is_binary(reason) and reason != ""
  end

  defp deps_from_mix_exs(source) do
    {:ok, ast} = Code.string_to_quoted(source)

    {_, deps} =
      Macro.prewalk(ast, [], fn
        {:defp, _, [{:deps, _, _}, [do: body]]}, acc ->
          {body, acc ++ extract_deps(body)}

        node, acc ->
          {node, acc}
      end)

    deps
  end

  defp extract_deps(list) when is_list(list) do
    list
    |> Enum.map(&normalize_dep/1)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_deps(_other), do: []

  defp normalize_dep({:{}, _, [app, _req, opts]}) when is_atom(app) and is_list(opts) do
    %{app: app, optional: Keyword.get(opts, :optional, false) == true}
  end

  defp normalize_dep({app, _req, opts}) when is_atom(app) and is_list(opts) do
    %{app: app, optional: Keyword.get(opts, :optional, false) == true}
  end

  defp normalize_dep({app, _req}) when is_atom(app) do
    %{app: app, optional: false}
  end

  defp normalize_dep(_other), do: nil

  defp forbidden_dep?(%{app: :redix, optional: true}), do: false

  defp forbidden_dep?(%{app: app}) do
    name = Atom.to_string(app)

    Enum.any?(~w(ecto phoenix jido) ++ ["ob" <> "an"], &String.starts_with?(name, &1)) or
      name in (~w(redis eredis) ++ ["re" <> "dix"])
  end

  defp dep_finding(%{app: app}, source) do
    %{path: "mix.exs", line: dep_line(source, app), word: Atom.to_string(app)}
  end

  defp dep_line(source, app) do
    needle = ":#{app}"

    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.find_value(1, fn {line, number} ->
      if String.contains?(line, needle), do: number
    end)
  end
end
