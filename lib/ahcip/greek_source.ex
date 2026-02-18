defmodule AHCIP.GreekSource do
  @moduledoc """
  Parses Greek source TEI XML files to provide line-by-line Greek text.

  Derives the Greek file path from the English TEI path by replacing
  `perseus-engN` with `perseus-grc2`.

  Uses `Kodon.TEIParser` legacy DOM helpers for xmerl-based parsing.
  """

  alias Kodon.TEIParser

  @doc """
  Derive the Greek TEI path from an English TEI path.

  ## Examples

      iex> AHCIP.GreekSource.greek_path("tlg0012/tlg001/tlg0012.tlg001.perseus-eng4.xml")
      "tlg0012/tlg001/tlg0012.tlg001.perseus-grc2.xml"
  """
  @spec greek_path(String.t()) :: String.t()
  def greek_path(english_path) do
    String.replace(english_path, ~r/perseus-eng\d+/, "perseus-grc2")
  end

  @doc """
  Parse Greek source text for a multi-book work (Iliad/Odyssey).

  Finds `<div>` elements with `subtype` matching "book" (case-insensitive),
  then extracts `<l n="N">` elements within each.

  Returns `%{book_number => %{line_number_string => "greek text"}}`.
  """
  @spec parse_books(Path.t()) :: %{integer() => %{String.t() => String.t()}}
  def parse_books(path) do
    doc = TEIParser.parse_xml(path)

    doc
    |> TEIParser.find_elements(:div)
    |> Enum.filter(fn elem ->
      subtype = TEIParser.get_attr(elem, :subtype)
      subtype != nil && String.downcase(subtype) == "book"
    end)
    |> Enum.map(&parse_book_lines/1)
    |> Enum.into(%{})
  end

  @doc """
  Parse Greek source text for a single hymn.

  Extracts `<l n="N">` elements from the edition div.
  Returns `%{1 => %{line_number_string => "greek text"}}`.
  """
  @spec parse_hymn(Path.t()) :: %{integer() => %{String.t() => String.t()}}
  def parse_hymn(path) do
    doc = TEIParser.parse_xml(path)

    lines =
      doc
      |> TEIParser.find_elements(:l)
      |> Enum.reduce(%{}, fn l_elem, acc ->
        case TEIParser.get_attr(l_elem, :n) do
          nil ->
            acc

          n_str ->
            text =
              l_elem
              |> TEIParser.extract_text()
              |> String.trim()
              |> TEIParser.collapse_whitespace()

            if text == "" do
              acc
            else
              Map.put(acc, n_str, text)
            end
        end
      end)

    %{1 => lines}
  end

  defp parse_book_lines(book_div) do
    book_number =
      case TEIParser.get_attr(book_div, :n) do
        nil -> 0
        str -> String.to_integer(str)
      end

    lines =
      book_div
      |> TEIParser.find_elements(:l)
      |> Enum.reduce(%{}, fn l_elem, acc ->
        case TEIParser.get_attr(l_elem, :n) do
          nil ->
            acc

          n_str ->
            text =
              l_elem
              |> TEIParser.extract_text()
              |> String.trim()
              |> TEIParser.collapse_whitespace()

            if text == "" do
              acc
            else
              Map.put(acc, n_str, text)
            end
        end
      end)

    {book_number, lines}
  end
end
