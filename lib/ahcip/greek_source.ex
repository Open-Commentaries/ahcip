defmodule AHCIP.GreekSource do
  @moduledoc """
  Parses Greek source TEI XML files to provide line-by-line Greek text.

  Derives the Greek file path from the English TEI path by replacing
  `perseus-engN` with `perseus-grc2`.

  Uses `Kodon.TEIParser` to parse the XML into structured elements, then
  walks the element tree to collect `<l n="N">` text regardless of nesting
  (e.g. lines inside `<q>` or other container elements).
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

  Finds textparts with `subtype` matching "book" (case-insensitive),
  collects all `<l n="N">` elements within each (including those nested
  inside other elements such as `<q>`), and extracts their text.

  Returns `%{book_number => %{line_number_string => "greek text"}}`.
  """
  @spec parse_books(Path.t()) :: %{integer() => %{String.t() => String.t()}}
  def parse_books(path) do
    parsed = TEIParser.parse(path)

    parsed.textparts
    |> Enum.filter(fn tp ->
      tp.subtype != nil && String.downcase(tp.subtype) == "book"
    end)
    |> Enum.into(%{}, fn book_tp ->
      book_number = String.to_integer(book_tp.n)

      book_elements =
        Enum.filter(parsed.elements, &(&1.textpart_urn == book_tp.urn))

      {book_number, collect_lines(book_elements)}
    end)
  end

  @doc """
  Parse Greek source text for a single hymn.

  Collects all `<l n="N">` elements from the parsed document (hymns have
  no book-level textparts — the edition div is the single textpart).

  Returns `%{1 => %{line_number_string => "greek text"}}`.
  """
  @spec parse_hymn(Path.t()) :: %{integer() => %{String.t() => String.t()}}
  def parse_hymn(path) do
    parsed = TEIParser.parse(path)
    %{1 => collect_lines(parsed.elements)}
  end

  # Walk a list of top-level elements and collect all <l n="N"> elements,
  # including those nested inside container elements (e.g. <q>, <sp>).
  # Returns %{n_string => text}.
  defp collect_lines(elements) do
    Enum.reduce(elements, %{}, fn el, acc ->
      l_elements =
        if el.tagname == "l" && Map.has_key?(el.attrs, "n") do
          [el | TEIParser.find_child_elements(el, "l")]
        else
          TEIParser.find_child_elements(el, "l")
        end
        |> Enum.filter(&Map.has_key?(&1.attrs, "n"))

      Enum.reduce(l_elements, acc, fn l_el, inner_acc ->
        n_str = l_el.attrs["n"]

        text =
          l_el
          |> TEIParser.full_text()
          |> String.trim()
          |> TEIParser.collapse_whitespace()

        if text == "", do: inner_acc, else: Map.put(inner_acc, n_str, text)
      end)
    end)
  end
end
