defmodule Mix.Tasks.Kodon.ExtractComments do
  @moduledoc """
  Extracts scholarly commentary from a PostgreSQL dump file to JSON.

  ## Usage

      mix kodon.extract_comments [dump_path]

  Parses the pg_dump file, filters to the homer project, selects the
  newest revision of each comment, and writes JSON to the output directory.

  If no dump path is given, uses the configured `commentary_dump_path`.
  """

  use Mix.Task

  @shortdoc "Extract comments from pg_dump to JSON"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    dump_path =
      case args do
        [path | _] -> path
        [] -> Application.get_env(:kodon, :commentary_dump_path)
      end

    output_dir = Application.get_env(:kodon, :output_dir)
    output_path = Path.join(output_dir, "comments.json")

    Mix.shell().info("Extracting comments...")
    Mix.shell().info("  Dump file: #{dump_path}")
    Mix.shell().info("  Output: #{output_path}")
    Mix.shell().info("")

    count = Kodon.CommentExtractor.extract(dump_path, output_path)

    Mix.shell().info("Extracted #{count} comments to #{output_path}")
  end
end
