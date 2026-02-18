defmodule AHCIP.FallbackMerge do
  @moduledoc """
  Detects gaps in scholar translations and merges with fallback TEI elements.

  Takes a `%Kodon.TEIParser{}` struct and a `%Kodon.Book{}` with scholar
  translations, producing a mixed list of scholar lines and fallback gaps.

  Gaps contain the original TEI elements (not flat text), which can be
  pre-rendered via `Kodon.Renderer.render_children/1` before passing to
  templates.
  """

  alias Kodon.{Book, Line}
  alias Kodon.TEIParser
  alias Kodon.TEIParser.Element

  @type content_item ::
          {:scholar_line, Line.t()}
          | {:fallback_gap, gap_info()}

  @type gap_info :: %{
          start_line: integer(),
          end_line: integer(),
          elements: [Element.t()],
          rendered_html: String.t() | nil
        }

  @doc """
  Merge a scholar book with fallback TEI data.

  Returns a list of content items in line-number order:
  - `{:scholar_line, %Line{}}` for translated lines
  - `{:fallback_gap, %{start_line, end_line, elements, rendered_html}}` for gaps

  ## Parameters

  - `book` — `%Book{}` with scholar translations (may have empty `lines`)
  - `parsed` — `%TEIParser{}` struct from SAX parsing
  - `tei_format` — `:book_card_milestone` or `:line_elements`
  - `book_number` — which book/section to extract from the TEI
  - `opts` — keyword list; pass `render: true` to pre-render gap elements to HTML
  """
  @spec merge(Book.t(), TEIParser.t(), atom(), integer(), keyword()) :: [content_item()]
  def merge(book, parsed, tei_format, book_number, opts \\ []) do
    line_data = extract_line_data(parsed, tei_format, book_number)
    last_line = last_line_number(line_data)

    items =
      if length(book.lines) == 0 do
        if last_line > 0 do
          elements = elements_for_range(line_data, 1, last_line)
          [{:fallback_gap, %{start_line: 1, end_line: last_line, elements: elements, rendered_html: nil}}]
        else
          []
        end
      else
        merge_with_gaps(book, line_data, last_line)
      end

    if Keyword.get(opts, :render, false) do
      Enum.map(items, fn
        {:fallback_gap, gap} ->
          html = Kodon.Renderer.render_children(gap.elements)
          {:fallback_gap, %{gap | rendered_html: html}}

        other ->
          other
      end)
    else
      items
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

  # --- Line data extraction ---

  # For book_card_milestone: extract milestone-based line info from <p> elements
  # For line_elements: extract <l n="N"> elements

  defp extract_line_data(parsed, :book_card_milestone, book_number) do
    book_n = to_string(book_number)

    # Find textparts for this book (cards within the book)
    book_textpart_urns =
      parsed.textparts
      |> Enum.filter(fn tp ->
        case tp.location do
          [^book_n | _] -> true
          _ -> false
        end
      end)
      |> Enum.map(& &1.urn)
      |> MapSet.new()

    # Get elements belonging to these textparts
    elements =
      parsed.elements
      |> Enum.filter(&MapSet.member?(book_textpart_urns, &1.textpart_urn))

    # Extract milestone line numbers and associate with parent elements
    milestones =
      elements
      |> Enum.flat_map(fn el ->
        el.children
        |> Enum.filter(fn
          %Element{tagname: "milestone", attrs: %{"unit" => "line"}} -> true
          _ -> false
        end)
        |> Enum.map(fn ms ->
          {String.to_integer(ms.attrs["n"]), el}
        end)
      end)
      |> Enum.sort_by(&elem(&1, 0))

    {:milestone, milestones, elements}
  end

  defp extract_line_data(parsed, :line_elements, _book_number) do
    # For hymns, all <l> elements are direct top-level elements
    l_elements =
      parsed.elements
      |> Enum.filter(&(&1.tagname == "l" && &1.attrs["n"] != nil))
      |> Enum.map(fn el ->
        {String.to_integer(el.attrs["n"]), el}
      end)
      |> Enum.sort_by(&elem(&1, 0))

    # Also collect non-line elements (like <head>) for context
    other_elements =
      parsed.elements
      |> Enum.filter(&(&1.tagname != "l"))

    {:line, l_elements, other_elements}
  end

  defp last_line_number({:milestone, milestones, _elements}) do
    case milestones do
      [] -> 0
      list -> list |> List.last() |> elem(0)
    end
  end

  defp last_line_number({:line, l_elements, _other}) do
    case l_elements do
      [] -> 0
      list -> list |> List.last() |> elem(0)
    end
  end

  defp elements_for_range({:milestone, milestones, _elements}, start_line, end_line) do
    # Collect parent elements that contain milestones in the range
    milestones
    |> Enum.filter(fn {n, _el} -> n >= start_line && n <= end_line end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.uniq_by(& &1.index)
  end

  defp elements_for_range({:line, l_elements, _other}, start_line, end_line) do
    l_elements
    |> Enum.filter(fn {n, _el} -> n >= start_line && n <= end_line end)
    |> Enum.map(&elem(&1, 1))
  end

  # --- Gap detection (same algorithm as old ButlerFallback) ---

  defp merge_with_gaps(book, line_data, last_line) do
    scholar_lines =
      book.lines
      |> Enum.map(fn line -> {elem(line.sort_key, 0), line} end)
      |> Enum.sort_by(&elem(&1, 0))

    first_scholar = elem(List.first(scholar_lines), 0)
    last_scholar = elem(List.last(scholar_lines), 0)

    items = []

    # Gap before first scholar line
    items =
      if first_scholar > 1 do
        items ++ make_gap(line_data, 1, first_scholar - 1)
      else
        items
      end

    # Interleave scholar lines and gaps between them
    items = items ++ interleave_lines_and_gaps(scholar_lines, line_data)

    # Gap after last scholar line
    if last_scholar < last_line do
      items ++ make_gap(line_data, last_scholar + 1, last_line)
    else
      items
    end
  end

  defp interleave_lines_and_gaps(scholar_lines, line_data) do
    scholar_lines
    |> Enum.chunk_every(2, 1)
    |> Enum.flat_map(fn
      [{_line_num, line}, {next_num, _}] ->
        current_num = elem(line.sort_key, 0)
        gap_start = current_num + 1
        gap_end = next_num - 1

        scholar = [{:scholar_line, line}]

        if gap_end >= gap_start do
          scholar ++ make_gap(line_data, gap_start, gap_end)
        else
          scholar
        end

      [{_line_num, line}] ->
        [{:scholar_line, line}]
    end)
  end

  defp make_gap(line_data, start_line, end_line) do
    # Only create a gap if it spans at least 2 lines
    if end_line - start_line >= 1 do
      elements = elements_for_range(line_data, start_line, end_line)

      if elements != [] do
        [{:fallback_gap, %{start_line: start_line, end_line: end_line, elements: elements, rendered_html: nil}}]
      else
        []
      end
    else
      []
    end
  end
end
