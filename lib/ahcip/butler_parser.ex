defmodule AHCIP.ButlerParser do
  @moduledoc """
  Parses the Butler translation TEI XML into a structured lookup.

  Uses Erlang's built-in :xmerl for XML parsing (no external dependencies).
  """

  @type segment :: %{
          start_line: integer(),
          text: String.t()
        }

  @type butler_data :: %{integer() => [segment()]}

  @doc """
  Parse the Butler TEI XML file and return a lookup map.

  Returns `%{book_number => [%{start_line: N, text: "..."}]}` sorted by start_line.
  """
  def parse_file(path) do
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
    |> find_elements(:div)
    |> Enum.filter(&(get_attr(&1, :subtype) == "book"))
    |> Enum.map(&parse_book/1)
    |> Enum.into(%{})
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

  @doc """
  Look up Butler text for a given book and line range.
  """
  def lookup(butler_data, book_number, start_line, end_line) do
    segments = Map.get(butler_data, book_number, [])

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
  Get the approximate last line number for a book.
  """
  def book_last_line(butler_data, book_number) do
    segments = Map.get(butler_data, book_number, [])

    case List.last(segments) do
      nil -> 0
      last -> last.start_line + 20
    end
  end

  # Tree walking helpers

  defp find_elements(node, tag_name) do
    case node do
      {:xmlElement, ^tag_name, _, _, _, _, _, _, content, _, _, _} ->
        # This node matches — return it, and also search children
        [node | Enum.flat_map(content, &find_elements(&1, tag_name))]

      {:xmlElement, _, _, _, _, _, _, _, content, _, _, _} ->
        # Different tag — search children
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
