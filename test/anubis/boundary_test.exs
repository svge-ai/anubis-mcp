defmodule Anubis.BoundaryTest do
  use ExUnit.Case, async: false

  @token "th" <> "read"
  @extra "liv" <> "eskill"
  @sync_doc "SV" <> "GE.md"
  @held "le" <> "ase"
  @host "api.service." <> "internal"
  @job "ob" <> "an"

  test "fails when lib contains the probed token" do
    path = probe!(@token)

    assert {:error, findings} = Anubis.Boundary.check()

    assert Enum.any?(findings, fn finding ->
             finding.path == relative(path) and String.downcase(finding.word) == @token
           end)
  end

  test "fails when lib contains the extra leaked name" do
    path = probe!(@extra)

    assert {:error, findings} = Anubis.Boundary.check()

    assert Enum.any?(findings, fn finding ->
             finding.path == relative(path) and String.downcase(finding.word) == @extra
           end)
  end

  test "the working tree passes" do
    assert :ok = Anubis.Boundary.check()
  end

  test "does not scan the sync doc, the allow file, or the changelog" do
    root = briefly!()
    File.write!(Path.join(root, @sync_doc), @token <> "\n")
    File.write!(Path.join(root, "CHANGELOG.md"), @held <> "\n")
    File.mkdir_p!(Path.join(root, "config"))

    File.write!(Path.join(root, "config/boundary_allow.exs"), """
    [%{file: "x", line: 1, word: #{inspect(@token)}, reason: "kept"}]
    """)

    assert :ok = Anubis.Boundary.scan(root, deny: [@token, @held], allow: [])
  end

  test "a private hostname fails and a field name does not" do
    root = briefly!()
    lib = Path.join(root, "lib")
    File.mkdir_p!(lib)
    host = Path.join(lib, "host.ex")
    File.write!(host, "host = #{inspect(@host)}\n")

    assert {:error, findings} =
             Anubis.Boundary.scan(root,
               deny: ["/(?:[a-z0-9-]+\\.)+internal(?![a-z0-9_-])/"],
               allow: []
             )

    assert Enum.any?(findings, &String.ends_with?(&1.word, "internal"))

    File.write!(host, "name = @error_messages.internal_error\n")

    assert :ok =
             Anubis.Boundary.scan(root, deny: Anubis.Boundary.deny_entries(File.cwd!()), allow: [])
  end

  test "optional redix is allowed and the other product deps are not" do
    assert :ok = Anubis.Boundary.dependencies(File.read!("mix.exs"))

    source = """
    defp deps do
      [
        {:redix, "~> 1.9", optional: true},
        {:plug, "~> 1.20", optional: true},
        {:ecto, "~> 3.0"},
        {#{inspect(String.to_atom(@job))}, "~> 2.0"},
        {:phoenix, "~> 1.7"},
        {:jido, "~> 1.0"},
        {:redis, "~> 1.0"},
        {:redix, "~> 1.9"}
      ]
    end
    """

    assert {:error, findings} = Anubis.Boundary.dependencies(source)
    words = Enum.map(findings, & &1.word)
    assert "ecto" in words
    assert @job in words
    assert "phoenix" in words
    assert "jido" in words
    assert "redis" in words
    assert "redix" in words
    refute "plug" in words
  end

  defp probe!(word) do
    path =
      Path.join(
        File.cwd!(),
        "lib/anubis/boundary_probe_#{System.unique_integer([:positive])}.ex"
      )

    File.write!(path, "defmodule Probe do\n  @word #{inspect(word)}\nend\n")
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp relative(path), do: Path.relative_to(path, File.cwd!())

  defp briefly! do
    dir = Path.join(System.tmp_dir!(), "anubis-boundary-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end
end
