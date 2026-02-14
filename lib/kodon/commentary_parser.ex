defmodule Kodon.CommentaryParser do
  @moduledoc """
  Parses per-author commentary markdown files from the `commentary/` directory
  into comment maps suitable for rendering in the site.
  """

  alias Kodon.CommentExtractor

  @doc """
  Load all commentary files from `commentary_dir` and return a flat list of comment maps.
  """
  def load(commentary_dir) do
    Path.wildcard(Path.join(commentary_dir, "*.md"))
    |> Enum.flat_map(&parse_file/1)
  end

  @doc """
  Parse a single per-author markdown file into a list of comment maps.
  """
  def parse_file(path) do
    content = File.read!(path)

    {author, body} = split_front_matter(content)

    body
    |> split_comments()
    |> Enum.map(&parse_comment(&1, author))
    |> Enum.reject(&is_nil/1)
  end

  defp split_front_matter(content) do
    case Regex.run(~r/\A---\n(.*?)\n---\n(.*)\z/s, content) do
      [_, yaml, body] ->
        author =
          case Regex.run(~r/^author:\s*(.+)$/m, yaml) do
            [_, name] -> String.trim(name)
            _ -> "Unknown"
          end

        {author, body}

      _ ->
        {"Unknown", content}
    end
  end

  defp split_comments(body) do
    body
    |> String.split(~r/\n---\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  @doc """
  Parse a single comment block (URN line + metadata lines + markdown body)
  into a comment map with the fields the template expects.
  """
  def parse_comment(block, author) do
    lines = String.split(block, "\n")

    case lines do
      ["@" <> urn | rest] ->
        {metadata, body_lines} = split_metadata(rest)
        markdown_body = Enum.join(body_lines, "\n") |> String.trim()

        content_html =
          case Earmark.as_html(markdown_body, smartypants: true) do
            {:ok, html, _} -> html
            {:error, html, _} -> html
          end

        urn_info = CommentExtractor.parse_urn(urn)

        contributors =
          case Map.get(metadata, "contributors") do
            nil ->
              []

            val ->
              val |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
          end

        authors = [author | contributors]

        %{
          "start_line" => urn_info.start_line,
          "end_line" => urn_info.end_line,
          "work" => urn_info.work,
          "book" => urn_info.book,
          "authors" => authors,
          "content_html" => content_html,
          "title" => Map.get(metadata, "title"),
          "urn" => urn,
          "citation_urn" => Map.get(metadata, "citation_urn")
        }

      _ ->
        nil
    end
  end

  defp split_metadata(lines) do
    {meta_lines, body_lines} =
      Enum.split_while(lines, fn line ->
        String.starts_with?(line, ":") or line == ""
      end)

    metadata =
      meta_lines
      |> Enum.reject(&(&1 == ""))
      |> Enum.reduce(%{}, fn line, acc ->
        case Regex.run(~r/^:(\w+):\s*(.*)$/, line) do
          [_, key, value] -> Map.put(acc, key, String.trim(value))
          _ -> acc
        end
      end)

    {metadata, body_lines}
  end
end
