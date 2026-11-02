defmodule Anubis.Boundary do
  @moduledoc """
  Scans a tree for denied words.

  `mix anubis.boundary` uses `config/boundary_deny.txt` and
  `config/boundary_allow.txt`. The allow list is paths, not names.
  """

  @deny_file "config/boundary_deny.txt"
  @allow_file "config/boundary_allow.txt"
  @max_bytes 2_000_000
  @skip_dirs ~w(.git deps _build cover .elixir_ls node_modules)

  @type finding :: %{path: String.t(), line: pos_integer(), word: String.t()}

  @spec check() :: :ok | {:error, [finding()]}
  def check, do: check(File.cwd!())

  @spec check(Path.t()) :: :ok | {:error, [finding()]}
  def check(root) when is_binary(root) do
    scan(root, deny: deny_words(root), allow: allow_paths(root))
  end

  @spec deny_words(Path.t()) :: [String.t()]
  def deny_words(root) when is_binary(root) do
    load_list(Path.join(root, @deny_file))
  end

  @spec allow_paths(Path.t()) :: [String.t()]
  def allow_paths(root) when is_binary(root) do
    load_list(Path.join(root, @allow_file))
  end

  @spec scan(Path.t(), keyword()) :: :ok | {:error, [finding()]}
  def scan(root, opts) when is_binary(root) and is_list(opts) do
    deny = Keyword.fetch!(opts, :deny)
    allow = Keyword.get(opts, :allow, [])

    regex = compile(deny)

    findings =
      root
      |> files()
      |> Enum.flat_map(&scan_file(&1, root, regex, allow))
      |> Enum.sort_by(&{&1.path, &1.line, &1.word})

    if findings == [], do: :ok, else: {:error, findings}
  end

  defp compile([]) do
    raise ArgumentError, "boundary deny list is empty"
  end

  defp compile(words) do
    body = Enum.map_join(words, "|", &Regex.escape/1)
    {:ok, regex} = Regex.compile("(?i)(?<![A-Za-z0-9])(?:#{body})(?![A-Za-z0-9])")
    regex
  end

  defp files(root) do
    root
    |> walk([])
    |> Enum.sort()
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

  defp scan_file(path, root, regex, allow) do
    rel = Path.relative_to(path, root)

    if allowed?(rel, allow) or not text?(path) do
      []
    else
      findings_in(path, rel, regex)
    end
  end

  defp findings_in(path, rel, regex) do
    path
    |> File.stream!()
    |> Stream.with_index(1)
    |> Enum.flat_map(&findings_on_line(&1, rel, regex))
  end

  defp findings_on_line({line, number}, rel, regex) do
    regex
    |> Regex.scan(line)
    |> Enum.map(fn [word | _] -> %{path: rel, line: number, word: word} end)
  end

  defp allowed?(path, allow) do
    Enum.any?(allow, fn entry ->
      entry = String.trim_trailing(entry, "/")
      path == entry or String.starts_with?(path, entry <> "/")
    end)
  end

  defp text?(path) do
    case File.read(path) do
      {:ok, bin} -> String.valid?(bin) and not String.contains?(bin, <<0>>)
      _ -> false
    end
  end

  defp load_list(path) do
    path
    |> File.read!()
    |> String.split(~r/\R/u, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  end
end
