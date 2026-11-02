defmodule Mix.Tasks.Anubis.Boundary do
  @shortdoc "Fail if a denied word or dependency leaked into the tree"
  @moduledoc """
  Scans `lib/` and `test/` for denied words, and checks `mix.exs` deps.

      mix anubis.boundary

  Words come from `config/boundary_deny.txt`. A `/regex/` line is a regex.
  `config/boundary_allow.exs` allows a single file, line, and word.
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
