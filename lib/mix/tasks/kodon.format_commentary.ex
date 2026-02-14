defmodule Mix.Tasks.Kodon.FormatCommentary do
  @moduledoc """
  Formats extracted comments into per-author commentary markdown files.

  ## Usage

      mix kodon.format_commentary [json_path] [output_dir]

  Reads comments from JSON (default: output/comments.json), groups by
  primary author, and writes one markdown file per author to the output
  directory (default: commentary/).
  """

  use Mix.Task

  @shortdoc "Format comments.json into per-author commentary markdown"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {json_path, output_dir} =
      case args do
        [json, dir | _] -> {json, dir}
        [json | _] -> {json, "commentary"}
        [] -> {Path.join(Application.get_env(:kodon, :output_dir, "output"), "comments.json"), "commentary"}
      end

    Mix.shell().info("Formatting commentary...")
    Mix.shell().info("  Source: #{json_path}")
    Mix.shell().info("  Output: #{output_dir}")
    Mix.shell().info("")

    results = Kodon.CommentaryFormatter.format(json_path, output_dir)

    for {filename, count} <- results do
      Mix.shell().info("  #{filename}: #{count} comments")
    end

    total = results |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    Mix.shell().info("")
    Mix.shell().info("Wrote #{length(results)} files (#{total} comments total)")
  end
end
