defmodule AHCIP.ButlerFallback do
  @moduledoc """
  Detects gaps in scholar translations and merges with Butler fallback text.

  Option B approach: main text shows only scholar translations. Gaps show a notice
  "Lines X-Y: Scholar translation not yet available" with expandable Butler text.
  """

  alias AHCIP.{Book, Line}

  @type content_item ::
          {:scholar_line, Line.t()}
          | {:butler_gap, gap_info()}

  @type gap_info :: %{
          start_line: integer(),
          end_line: integer(),
          butler_text: String.t()
        }

  @doc """
  Merge a scholar book with Butler fallback data.

  Returns a list of content items in line-number order:
  - `{:scholar_line, %Line{}}` for translated lines
  - `{:butler_gap, %{start_line, end_line, butler_text}}` for gaps
  """
  def merge(book, butler_data) do
    butler_last_line = AHCIP.ButlerParser.book_last_line(butler_data, book.number)

    if length(book.lines) == 0 do
      # Entire book is Butler fallback
      butler_text = AHCIP.ButlerParser.lookup(butler_data, book.number, 1, butler_last_line)

      if butler_text != "" do
        [{:butler_gap, %{start_line: 1, end_line: butler_last_line, butler_text: butler_text}}]
      else
        []
      end
    else
      merge_with_gaps(book, butler_data, butler_last_line)
    end
  end

  defp merge_with_gaps(book, butler_data, butler_last_line) do
    # Get sorted scholar line numbers as integers
    scholar_lines =
      book.lines
      |> Enum.map(fn line -> {elem(line.sort_key, 0), line} end)
      |> Enum.sort_by(&elem(&1, 0))

    first_scholar = elem(List.first(scholar_lines), 0)
    last_scholar = elem(List.last(scholar_lines), 0)

    # Build gaps before, between, and after scholar lines
    items = []

    # Gap before first scholar line
    items =
      if first_scholar > 1 do
        gap = make_gap(butler_data, book.number, 1, first_scholar - 1)
        items ++ gap
      else
        items
      end

    # Interleave scholar lines and gaps between them
    items = items ++ interleave_lines_and_gaps(scholar_lines, butler_data, book.number)

    # Gap after last scholar line
    if last_scholar < butler_last_line do
      gap = make_gap(butler_data, book.number, last_scholar + 1, butler_last_line)
      items ++ gap
    else
      items
    end
  end

  defp interleave_lines_and_gaps(scholar_lines, butler_data, book_number) do
    scholar_lines
    |> Enum.chunk_every(2, 1)
    |> Enum.flat_map(fn
      [{_line_num, line}, {next_num, _}] ->
        current_num = elem(line.sort_key, 0)
        gap_start = current_num + 1
        gap_end = next_num - 1

        scholar = [{:scholar_line, line}]

        if gap_end >= gap_start do
          scholar ++ make_gap(butler_data, book_number, gap_start, gap_end)
        else
          scholar
        end

      [{_line_num, line}] ->
        # Last line, no gap after (handled by caller)
        [{:scholar_line, line}]
    end)
  end

  defp make_gap(butler_data, book_number, start_line, end_line) do
    # Only create a gap if it spans at least 2 lines (small gaps between
    # contiguous lines with sub-numbers like 40a are not real gaps)
    if end_line - start_line >= 1 do
      butler_text = AHCIP.ButlerParser.lookup(butler_data, book_number, start_line, end_line)

      if butler_text != "" do
        [{:butler_gap, %{start_line: start_line, end_line: end_line, butler_text: butler_text}}]
      else
        []
      end
    else
      []
    end
  end

  @doc """
  Create a book title for display, using either the scholar title or a default.
  """
  def display_title(%Book{title: title}) when is_binary(title), do: title

  def display_title(%Book{number: number}) do
    "Scroll #{number}"
  end
end
