defmodule Kodon.TEIParser do
  @moduledoc """
  Parses TEI XML translations into structured lookups.

  Supports two formats:
  - `:book_card_milestone` — Used by Iliad and Odyssey (Butler/Power/Nagy translations).
    Structure: `<div subtype="book">` → `<div subtype="card">` → `<p>` with `<milestone unit="line">`.
  - `:line_elements` — Used by Homeric Hymns (Evelyn-White translation).
    Structure: `<div type="translation">` → `<l n="N">` elements.

  Uses Erlang's built-in :xmerl for XML parsing (no external dependencies).
  """

  @type segment :: %{
          start_line: integer(),
          text: String.t()
        }

  @type tei_data :: %{integer() => [segment()]}

  @doc """
  Parse a TEI XML file and return a lookup map.

  Returns `%{section_number => [%{start_line: N, text: "..."}]}` sorted by start_line.
  For `:book_card_milestone`, section_number is the book number.
  For `:line_elements`, there is a single section `1` containing all lines,
  and the result includes a `:title` key with the hymn title from the `<head>` element.
  """
  def parse_file(path, format \\ :book_card_milestone)

  def parse_file(path, :book_card_milestone) do
    doc = parse_xml(path)

    doc
    |> find_elements(:div)
    |> Enum.filter(&(get_attr(&1, :subtype) == "book"))
    |> Enum.map(&parse_book/1)
    |> Enum.into(%{})
  end

  def parse_file(path, :line_elements) do
    doc = parse_xml(path)

    # Find the translation div
    translation_div =
      doc
      |> find_elements(:div)
      |> Enum.find(&(get_attr(&1, :type) == "translation"))

    case translation_div do
      nil ->
        %{title: nil, sections: %{1 => []}}

      div ->
        title = extract_head_title(div)
        lines = extract_line_elements(div)
        %{title: title, sections: %{1 => lines}}
    end
  end

  defp parse_xml(path) do
    xml =
      path
      |> File.read!()
      |> String.replace(~r/<\?xml-model[^?]*\?>\s*/, "")
      |> String.replace(~r/ xmlns="[^"]*"/, "")

    {doc, _} =
      xml
      |> :binary.bin_to_list()
      |> :xmerl_scan.string(quiet: true)

    doc
  end

  defp parse_book(book_div) do
    book_number =
      case get_attr(book_div, :n) do
        nil -> 0
        str -> String.to_integer(str)
      end

    segments =
      book_div
      |> find_elements(:div)
      |> Enum.filter(&(get_attr(&1, :subtype) == "card"))
      |> Enum.flat_map(&parse_card/1)
      |> Enum.sort_by(& &1.start_line)

    {book_number, segments}
  end

  defp parse_card(card_div) do
    card_div
    |> find_elements(:p)
    |> Enum.map(&parse_paragraph/1)
    |> Enum.reject(fn seg -> seg.text == "" end)
  end

  defp parse_paragraph(p_elem) do
    milestones =
      p_elem
      |> find_elements(:milestone)
      |> Enum.filter(&(get_attr(&1, :unit) == "line"))

    start_line =
      case milestones do
        [first | _] ->
          case get_attr(first, :n) do
            nil -> 0
            str -> String.to_integer(str)
          end

        [] ->
          0
      end

    text =
      p_elem
      |> extract_text()
      |> String.trim()
      |> collapse_whitespace()

    %{start_line: start_line, text: text}
  end

  defp extract_head_title(div) do
    case find_elements(div, :head) do
      [head | _] ->
        head
        |> extract_text()
        |> String.trim()
        |> collapse_whitespace()

      [] ->
        nil
    end
  end

  defp extract_line_elements(div) do
    div
    |> find_elements(:l)
    |> Enum.map(fn l_elem ->
      line_num =
        case get_attr(l_elem, :n) do
          nil ->
            0

          str ->
            case Integer.parse(str) do
              {n, _} -> n
              :error -> 0
            end
        end

      text =
        l_elem
        |> extract_text()
        |> String.trim()
        |> collapse_whitespace()

      %{start_line: line_num, text: text}
    end)
    |> Enum.reject(fn seg -> seg.text == "" end)
    |> Enum.sort_by(& &1.start_line)
  end

  @doc """
  Look up text for a given section and line range.
  """
  def lookup(tei_data, section_number, start_line, end_line) do
    # Handle both plain map and %{sections: map} format
    segments =
      case tei_data do
        %{sections: sections} -> Map.get(sections, section_number, [])
        _ -> Map.get(tei_data, section_number, [])
      end

    segments
    |> Enum.filter(fn seg ->
      seg.start_line <= end_line && segment_end(seg, segments) > start_line
    end)
    |> Enum.map(& &1.text)
    |> Enum.join("\n\n")
  end

  defp segment_end(seg, all_segments) do
    all_segments
    |> Enum.filter(&(&1.start_line > seg.start_line))
    |> Enum.map(& &1.start_line)
    |> Enum.min(fn -> seg.start_line + 100 end)
  end

  @doc """
  Get the approximate last line number for a section.
  """
  def book_last_line(tei_data, section_number) do
    segments =
      case tei_data do
        %{sections: sections} -> Map.get(sections, section_number, [])
        _ -> Map.get(tei_data, section_number, [])
      end

    case List.last(segments) do
      nil -> 0
      last -> last.start_line + 20
    end
  end

  # Tree walking helpers

  defp find_elements(node, tag_name) do
    case node do
      {:xmlElement, ^tag_name, _, _, _, _, _, _, content, _, _, _} ->
        [node | Enum.flat_map(content, &find_elements(&1, tag_name))]

      {:xmlElement, _, _, _, _, _, _, _, content, _, _, _} ->
        Enum.flat_map(content, &find_elements(&1, tag_name))

      _ ->
        []
    end
  end

  defp get_attr(elem, name) do
    case elem do
      {:xmlElement, _, _, _, _, _, _, attrs, _, _, _, _} ->
        Enum.find_value(attrs, nil, fn
          {:xmlAttribute, ^name, _, _, _, _, _, _, value, _} ->
            to_string(value)

          _ ->
            nil
        end)

      _ ->
        nil
    end
  end

  defp extract_text(node) do
    case node do
      {:xmlElement, _, _, _, _, _, _, _, content, _, _, _} ->
        content |> Enum.map(&extract_text/1) |> Enum.join()

      {:xmlText, _, _, _, value, _} ->
        to_string(value)

      _ ->
        ""
    end
  end

  defp collapse_whitespace(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
