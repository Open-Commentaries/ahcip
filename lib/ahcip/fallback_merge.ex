defmodule AHCIP.FallbackMerge do
  @moduledoc """
  Detects gaps in scholar translations and builds a mixed content list.

  Takes a `%Kodon.Book{}` with scholar translations and the parsed Greek lines
  for a section, producing an ordered list of scholar lines and fallback gaps.

  Gaps carry only start/end line numbers; the caller's template is responsible
  for looking up the Greek text from `greek_lines` and linking out to Scaife
  for translations.
  """

  alias Kodon.{Book, Line}

  @type content_item ::
          {:scholar_line, Line.t()}
          | {:fallback_gap, gap_info()}

  @type gap_info :: %{
          start_line: integer(),
          end_line: integer()
        }

  @doc """
  Merge a scholar book with Greek line data.

  Returns a list of content items in line-number order:
  - `{:scholar_line, %Line{}}` for translated lines
  - `{:fallback_gap, %{start_line, end_line}}` for untranslated ranges

  ## Parameters

  - `book` — `%Book{}` with scholar translations (may have empty `lines`)
  - `greek_lines` — `%{line_number_string => greek_text}` map for this section
  """
  @spec merge(Book.t(), %{String.t() => String.t()}) :: [content_item()]
  def merge(book, greek_lines) do
    last_line = last_greek_line(greek_lines)

    if length(book.lines) == 0 do
      if last_line > 0 do
        [{:fallback_gap, %{start_line: 1, end_line: last_line}}]
      else
        []
      end
    else
      merge_with_gaps(book, last_line)
    end
  end

  @doc """
  Create a display title for a section, with optional work context.
  """
  @spec display_title(Book.t(), map() | nil) :: String.t()
  def display_title(book, work \\ nil)

  def display_title(%Book{title: title}, _work) when is_binary(title), do: title

  def display_title(%Book{}, %{section_type: :hymn} = work) do
    "#{work.title}"
  end

  def display_title(%Book{number: number}, %{section_label: label}) do
    "#{label} #{number}"
  end

  def display_title(%Book{number: number}, _work) do
    "Scroll #{number}"
  end

  # --- Gap detection ---

  defp merge_with_gaps(book, last_line) do
    scholar_lines =
      book.lines
      |> Enum.map(fn line -> {elem(line.sort_key, 0), line} end)
      |> Enum.sort_by(&elem(&1, 0))

    first_scholar = elem(List.first(scholar_lines), 0)
    last_scholar = elem(List.last(scholar_lines), 0)

    items = []

    items =
      if first_scholar > 1 do
        items ++ make_gap(1, first_scholar - 1)
      else
        items
      end

    items = items ++ interleave_lines_and_gaps(scholar_lines)

    if last_scholar < last_line do
      items ++ make_gap(last_scholar + 1, last_line)
    else
      items
    end
  end

  defp interleave_lines_and_gaps(scholar_lines) do
    scholar_lines
    |> Enum.chunk_every(2, 1)
    |> Enum.flat_map(fn
      [{_line_num, line}, {next_num, _}] ->
        current_num = elem(line.sort_key, 0)
        gap_start = current_num + 1
        gap_end = next_num - 1

        scholar = [{:scholar_line, line}]

        if gap_end >= gap_start do
          scholar ++ make_gap(gap_start, gap_end)
        else
          scholar
        end

      [{_line_num, line}] ->
        [{:scholar_line, line}]
    end)
  end

  defp make_gap(start_line, end_line) when end_line >= start_line do
    [{:fallback_gap, %{start_line: start_line, end_line: end_line}}]
  end

  defp make_gap(_start_line, _end_line), do: []

  # Determine the last line number from the Greek lines map.
  # Uses only the leading integer of each citation key (e.g. "132a" -> 132).
  defp last_greek_line(greek_lines) when map_size(greek_lines) == 0, do: 0

  defp last_greek_line(greek_lines) do
    greek_lines
    |> Map.keys()
    |> Enum.map(fn n_str ->
      case Integer.parse(n_str) do
        {n, _} -> n
        :error -> 0
      end
    end)
    |> Enum.max()
  end
end
