defmodule Kodon.CommentaryFormatter do
  @moduledoc """
  Reads comments.json, groups by primary author, and writes per-author
  commentary markdown files to the output directory.
  """

  alias Kodon.{HtmlToMarkdown, Renderer}

  @work_order %{"iliad" => 0, "odyssey" => 1, "hymn" => 2}

  @doc """
  Format comments from `json_path` into per-author markdown files in `output_dir`.
  Returns a list of `{filename, comment_count}` tuples.
  """
  def format(json_path, output_dir) do
    comments = json_path |> File.read!() |> Jason.decode!()
    File.mkdir_p!(output_dir)

    comments
    |> group_by_author()
    |> Enum.map(fn {author, author_comments} ->
      sorted = sort_comments(author_comments)
      filename = author_to_filename(author)
      path = Path.join(output_dir, filename)
      content = render_author_file(author, sorted)
      File.write!(path, content)
      {filename, length(sorted)}
    end)
    |> Enum.sort()
  end

  defp group_by_author(comments) do
    Enum.group_by(comments, fn comment ->
      case comment["authors"] do
        [primary | _] -> primary
        _ -> "Unknown"
      end
    end)
  end

  defp sort_comments(comments) do
    Enum.sort_by(comments, fn c ->
      {
        Map.get(@work_order, c["work"], 99),
        c["book"] || 0,
        c["start_line"] || 0,
        c["end_line"] || 0
      }
    end)
  end

  defp render_author_file(author, comments) do
    front_matter = """
    ---
    author: #{author}
    shortname: #{author_shortname(author)}
    ---
    """

    entries =
      comments
      |> Enum.map(&render_comment/1)
      |> Enum.join("\n---\n\n")

    front_matter <> "\n" <> entries
  end

  defp render_comment(comment) do
    lines = [urn_line(comment)]

    lines =
      lines ++
        contributors_line(comment) ++
        citation_urn_line(comment) ++
        timestamp_lines(comment)

    body = convert_content(comment["content"])

    metadata = Enum.join(lines, "\n")

    if body == "" do
      metadata <> "\n"
    else
      metadata <> "\n\n" <> body <> "\n"
    end
  end

  defp urn_line(comment) do
    "@" <> (comment["urn"] || "")
  end

  defp contributors_line(comment) do
    case comment["authors"] do
      [_ | rest] when rest != [] ->
        [":contributors: " <> Enum.join(rest, ", ")]

      _ ->
        []
    end
  end

  defp citation_urn_line(comment) do
    case comment["citation_urn"] do
      nil -> []
      "" -> []
      urn -> [":citation_urn: " <> urn]
    end
  end

  defp timestamp_lines(comment) do
    created = comment["created_at"]
    updated = comment["updated_at"]

    lines = if created, do: [":created_at: " <> created], else: []
    lines = if updated, do: lines ++ [":updated_at: " <> updated], else: lines
    lines
  end

  defp convert_content(nil), do: ""

  defp convert_content(%{"raw" => html}) do
    HtmlToMarkdown.convert(html)
  end

  defp convert_content(%{"blocks" => _} = draftjs) do
    draftjs
    |> Renderer.render_draftjs()
    |> HtmlToMarkdown.convert()
  end

  defp convert_content(_), do: ""

  @doc false
  def author_to_filename(name) do
    name
    |> String.downcase()
    |> strip_diacritics()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.trim()
    |> String.replace(~r/\s+/, "_")
    |> Kernel.<>(".md")
  end

  defp author_shortname(name) do
    name
    |> String.split()
    |> List.last("")
    |> String.downcase()
    |> strip_diacritics()
    |> String.replace(~r/[^a-z]/, "")
  end

  defp strip_diacritics(str) do
    str
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{M}/u, "")
  end
end
