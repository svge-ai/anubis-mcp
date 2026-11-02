defmodule Mix.Tasks.Anubis.Boundary do
  @shortdoc "Fail if a denied word leaked into the tree"
  @moduledoc """
  Scans the working tree for denied words.

      mix anubis.boundary

  Words come from `config/boundary_deny.txt`. Paths in
  `config/boundary_allow.txt` are skipped. The allow list holds paths only.
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    case Anubis.Boundary.check() do
      :ok ->
        Mix.shell().info("Boundary check passed")

      {:error, findings} ->
        Enum.each(findings, fn %{path: path, line: line, word: word} ->
          Mix.shell().error("#{path}:#{line}: #{word}")
        end)

        Mix.raise("boundary check failed (#{length(findings)})")
    end
  end
end
