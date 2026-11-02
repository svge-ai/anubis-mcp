defmodule Anubis.BoundaryTest do
  use ExUnit.Case, async: true

  test "fails on a leaked word" do
    root = File.cwd!()
    words = Anubis.Boundary.deny_words(root)
    leaked = File.read!(Path.join(root, "test/fixtures/boundary/leaked.txt"))
    dir = temp_tree!(words, leaked, allow: "config/boundary_deny.txt\n")

    assert {:error, findings} = Anubis.Boundary.check(dir)
    assert findings != []

    assert Enum.all?(findings, fn finding ->
             String.contains?(String.downcase(leaked), String.downcase(finding.word))
           end)
  end

  test "the working tree passes" do
    assert :ok = Anubis.Boundary.check(File.cwd!())
  end

  test "the allow list contains no denied word" do
    root = File.cwd!()
    words = Anubis.Boundary.deny_words(root)
    allow = File.read!(Path.join(root, "config/boundary_allow.txt"))

    assert :ok =
             Anubis.Boundary.scan(write_blob!(allow), deny: words, allow: [])
  end

  defp temp_tree!(words, leaked, allow: allow) do
    dir = Path.join(System.tmp_dir!(), "anubis-boundary-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(dir, "config"))
    File.write!(Path.join(dir, "config/boundary_deny.txt"), Enum.join(words, "\n") <> "\n")
    File.write!(Path.join(dir, "config/boundary_allow.txt"), allow)
    File.write!(Path.join(dir, "note.txt"), leaked)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  defp write_blob!(text) do
    dir = Path.join(System.tmp_dir!(), "anubis-boundary-blob-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "blob.txt"), text)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end
end
