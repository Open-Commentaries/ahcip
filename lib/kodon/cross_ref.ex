defmodule Kodon.CrossRef do
  @moduledoc """
  Handles cross-reference parsing and HTML link generation.

  Cross-refs use the format "I-BOOK.LINE" (e.g., "I-1.372").
  These are rendered as links to `/passages/<slug>/<book>.html#line-<book>-<line>`.
  """

  @doc """
  Parse a cross-reference string like "I-1.372" into {book, line}.
  Returns nil if the string doesn't match the expected format.
  """
  def parse(ref_string) do
    case Regex.run(~r/I-(\d+)\.(\d+[a-z]?)/, ref_string) do
      [_, book, line] -> {String.to_integer(book), line}
      _ -> nil
    end
  end

  @doc """
  Generate an HTML href for a cross-reference.

  Defaults to Iliad paths for backward compatibility with the "I-BOOK.LINE" format.
  """
  def to_href({book, line}) do
    to_href("tlg0012.tlg001", book, line)
  end

  def to_href(ref_string) when is_binary(ref_string) do
    case parse(ref_string) do
      nil -> "#"
      parsed -> to_href(parsed)
    end
  end

  @doc """
  Generate an HTML href with explicit work context.
  """
  def to_href(work_slug, book, line) do
    "/passages/#{work_slug}/#{book}.html#line-#{book}-#{line}"
  end

  @doc """
  Generate an HTML anchor id for a line.
  """
  def line_id(book_number, line_number) do
    "line-#{book_number}-#{line_number}"
  end

  @doc """
  Render a cross-reference "book.line" string as an HTML link.
  """
  def render_link(ref_string) do
    case Regex.run(~r/^(\d+)\.(\d+[a-z]?)$/, ref_string) do
      [_, book, line] ->
        href = to_href({String.to_integer(book), line})
        ~s(<a href="#{href}" class="cross-ref">#{book}.#{line}</a>)

      _ ->
        ref_string
    end
  end
end
