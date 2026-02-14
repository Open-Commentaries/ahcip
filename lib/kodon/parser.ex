defmodule Kodon.Parser do
  @moduledoc """
  Parses scholar translation .txt files into %Kodon.Book{} structs.

  Handles multiple format variations across the translation files:
  - Single long lines with no newlines between verses
  - Line-per-verse format
  - Hybrid formats mixing both
  - Tab-separated format (Iliad 22)
  """

  alias Kodon.{Book, Line, Annotation}

  # Matches line numbers like [1], [40a], [302 v.l.], [001]
  # Must NOT match [n:...], [=...], [me>nis], etc.
  # Key: line numbers contain ONLY digits, optional letter suffix, optional " v.l."
  @line_number_pattern ~r/\[(\d{1,3}[a-z]?(?:\s*v\.l\.)?)\]/

  # For splitting text on line numbers — captures the delimiter
  @line_split_pattern ~r/(\[\d{1,3}[a-z]?(?:\s*v\.l\.)?\])/

  @doc """
  Parse a scholar translation file into a %Book{} struct.
  """
  def parse_file(path) do
    content =
      path
      |> File.read!()
      |> preprocess()

    {preamble, title, translators, body} = extract_header(content)

    book_number = extract_book_number(title, path)

    lines =
      body
      |> split_into_verses()
      |> Enum.map(&parse_verse_line/1)
      |> Enum.sort_by(& &1.sort_key)

    %Book{
      number: book_number,
      title: title,
      preamble: preamble,
      translators: translators,
      lines: lines,
      source_file: path
    }
  end

  @doc """
  Preprocess raw file content: strip BOM, normalize quotes and whitespace.
  """
  def preprocess(content) do
    content
    |> String.replace(<<0xEF, 0xBB, 0xBF>>, "")
    # Apply byte-level replacements only for non-UTF-8 encoded files.
    # These raw byte replacements can corrupt valid UTF-8 multi-byte sequences
    # (e.g., byte 0x93 appears in the UTF-8 encoding of U+2013 en dash: E2 80 93).
    |> maybe_fix_encoding()
    # Normalize line endings: \r\n → \n, then lone \r → \n
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    # Unicode replacements (for properly encoded UTF-8 files)
    |> String.replace("\u2018", "'")
    |> String.replace("\u2019", "'")
    |> String.replace("\u201C", "\"")
    |> String.replace("\u201D", "\"")
    |> String.replace("\u2013", "--")
    |> String.replace("\u2014", "--")
    |> String.trim()
  end

  defp maybe_fix_encoding(content) do
    if String.valid?(content) do
      content
    else
      content
      # Mac Roman left double quote
      |> replace_byte(0xD2, "\"")
      # Mac Roman right double quote
      |> replace_byte(0xD3, "\"")
      # Mac Roman left single quote
      |> replace_byte(0xD4, "'")
      # Mac Roman right single quote
      |> replace_byte(0xD5, "'")
      # Mac Roman em dash
      |> replace_byte(0xD0, "--")
      # Mac Roman en dash
      |> replace_byte(0xD1, "--")
      # Mac Roman ellipsis
      |> replace_byte(0xC9, "...")
      # Windows-1252 left double quote
      |> replace_byte(0x93, "\"")
      # Windows-1252 right double quote
      |> replace_byte(0x94, "\"")
      # Windows-1252 left single quote
      |> replace_byte(0x91, "'")
      # Windows-1252 right single quote
      |> replace_byte(0x92, "'")
      # Windows-1252 en dash
      |> replace_byte(0x96, "--")
      # Windows-1252 em dash
      |> replace_byte(0x97, "--")
      |> sanitize_utf8()
    end
  end

  defp replace_byte(binary, byte, replacement) do
    :binary.replace(binary, <<byte>>, replacement, [:global])
  end

  defp sanitize_utf8(str) do
    if String.valid?(str) do
      str
    else
      str
      |> :unicode.characters_to_binary(:utf8, :utf8)
      |> case do
        {:error, valid, _rest} -> valid
        {:incomplete, valid, _rest} -> valid
        valid when is_binary(valid) -> valid
      end
    end
  end

  @doc """
  Extract header components: preamble, title, translators, and remaining body text.

  Header ordering varies across files:
  - Book 1: Preamble + "The Homeric Iliad" + "Translated by..." + "SCROLL I-1" + body
  - Books 2-5, etc.: "Iliad N" / "Iliad Scroll N" + "Translated by..." + body
  - Book 15: "Iliad 15" + "Translated by..." + body
  """
  def extract_header(content) do
    {preamble, rest} = extract_preamble(content)
    rest = strip_title_prefix(rest)

    # Try both orderings: translators-then-title, or title-then-translators
    case try_translators_first(rest) do
      {:ok, translators, title, body} ->
        {preamble, title, translators, body}

      :error ->
        case try_title_first(rest) do
          {:ok, translators, title, body} ->
            {preamble, title, translators, body}

          :error ->
            # Last resort: just look for [N] to find body start
            case Regex.run(~r/^(.*?)(\[\d)/, rest, capture: :all) do
              [_, header, bracket_start] ->
                {preamble, nil, [],
                 bracket_start <>
                   String.slice(
                     rest,
                     (String.length(header) + String.length(bracket_start))..-1//1
                   )}

              _ ->
                {preamble, nil, [], rest}
            end
        end
    end
  end

  defp extract_preamble(content) do
    if String.starts_with?(content, "Translators' Introduction:") do
      case Regex.run(
             ~r/^(Translators' Introduction:.*?)(?=The Homeric Iliad|Translated by)/s,
             content
           ) do
        [_, preamble] ->
          rest = String.slice(content, String.length(preamble)..-1//1) |> String.trim_leading()
          {String.trim(preamble), rest}

        _ ->
          {nil, content}
      end
    else
      {nil, content}
    end
  end

  defp strip_title_prefix(content) do
    Regex.replace(~r/^The Homeric Iliad\s*/, content, "")
  end

  # Order 1: "Translated by X...SCROLL I-1[body]" (on same line, limited length)
  defp try_translators_first(content) do
    case Regex.run(~r/^Translated by (.{5,200}?)(?=SCROLL\s+I-\d)/s, content) do
      [full_match, names_str] ->
        rest = String.slice(content, String.length(full_match)..-1//1) |> String.trim_leading()
        translators = parse_translator_names(names_str)

        case extract_title_from(rest) do
          {title, body} -> {:ok, translators, title, body}
          nil -> {:ok, translators, nil, rest}
        end

      _ ->
        :error
    end
  end

  # Order 2: "Iliad Scroll 3Translated by X...[body]"  or "Iliad 15Translated by X...[body]"
  defp try_title_first(content) do
    case extract_title_from(content) do
      {title, rest} ->
        case Regex.run(~r/^Translated by (.+?)(?=\[\d)/s, rest) do
          [full_match, names_str] ->
            body = String.slice(rest, String.length(full_match)..-1//1) |> String.trim_leading()
            translators = parse_translator_names(names_str)
            {:ok, translators, title, body}

          _ ->
            # Title found but no translators
            {:ok, [], title, rest}
        end

      nil ->
        # No title — try "Translated by X\n..." (tab-separated format like Iliad 22)
        # Take only the first line for translator names
        case Regex.run(~r/^Translated by ([^\n]+)\n(.*)/s, content) do
          [_, names_str, rest] ->
            translators = parse_translator_names(names_str)
            # Skip any section attributions (e.g., "437–501 translated by...")
            # and find where the actual verses start
            body =
              rest
              |> String.split("\n")
              |> Enum.drop_while(fn line ->
                trimmed = String.trim(line)
                trimmed == "" || Regex.match?(~r/^\d+.*translated by/i, trimmed)
              end)
              |> Enum.join("\n")

            {:ok, translators, nil, body}

          _ ->
            :error
        end
    end
  end

  defp extract_title_from(content) do
    case Regex.run(~r/^(SCROLL\s+I-\d+|Iliad\s+(?:Scroll\s+)?\d+)\s*/, content) do
      [full_match, title] ->
        rest = String.slice(content, String.length(full_match)..-1//1) |> String.trim_leading()
        {title, rest}

      _ ->
        nil
    end
  end

  defp parse_translator_names(names_str) do
    names_str
    |> String.split(~r/,\s*(?:and\s+)?|,?\s+and\s+/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  @doc """
  Extract the book number from a title string or filename.
  """
  def extract_book_number(title, path) do
    cond do
      title && Regex.match?(~r/I-(\d+)/, title) ->
        [_, num] = Regex.run(~r/I-(\d+)/, title)
        String.to_integer(num)

      title && Regex.match?(~r/(\d+)/, title) ->
        [_, num] = Regex.run(~r/(\d+)/, title)
        String.to_integer(num)

      true ->
        # Fall back to filename
        case Regex.run(~r/Iliad\s*(\d+)/, Path.basename(path)) do
          [_, num] -> String.to_integer(num)
          _ -> 0
        end
    end
  end

  @doc """
  Split body text into individual verse lines as {line_number, text} tuples.
  Handles bracket format ([N] text), tab-separated format (N\\ttext), and hybrids.
  """
  def split_into_verses(body) do
    bracket_verses = split_bracket_format(body)
    tab_verses = split_tab_format(body)

    # Use whichever format produced more results
    verses =
      if length(tab_verses) > length(bracket_verses) do
        tab_verses
      else
        bracket_verses
      end

    verses
    |> Enum.map(fn {number, text} -> {String.trim(number), String.trim(text)} end)
    |> Enum.reject(fn {number, _text} -> number == "" end)
  end

  defp split_bracket_format(body) do
    parts = Regex.split(@line_split_pattern, body, include_captures: true)

    parts
    |> chunk_line_parts()
  end

  defp split_tab_format(body) do
    # Match patterns like "437\ttext..." or "1440\ttext..."
    # The tab-separated format can have footnote numbers concatenated before the line number
    Regex.scan(~r/(?:^|\n|\r)(\d{1,3})\t([^\n\r]+)/s, body)
    |> Enum.map(fn [_, number, text] -> {number, text} end)
  end

  defp chunk_line_parts(parts) do
    parts
    |> Enum.reduce([], fn part, acc ->
      if Regex.match?(@line_number_pattern, part) do
        # This is a line number marker — extract the number
        [_, number] = Regex.run(@line_number_pattern, part)
        [{number, ""} | acc]
      else
        case acc do
          [{number, existing_text} | rest] ->
            [{number, existing_text <> part} | rest]

          [] ->
            # Text before first line number (skip — it's header remnant)
            acc
        end
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Parse a single verse line's text to extract annotations and clean text.
  """
  def parse_verse_line({number, raw_text}) do
    {clean_text, annotations} = extract_annotations(raw_text)

    %Line{
      number: number,
      sort_key: Line.sort_key(number),
      text: clean_text |> String.trim() |> collapse_whitespace(),
      raw_text: String.trim(raw_text),
      annotations: annotations
    }
  end

  @doc """
  Extract all bracketed annotations from text, returning {clean_text, annotations}.
  """
  def extract_annotations(text) do
    # First pass: extract [[...]] double-bracket editorial markers
    {text, editorial_annotations} = extract_double_brackets(text)

    # Second pass: extract [...] single-bracket markers
    {clean_text, single_annotations} = extract_single_brackets(text)

    {clean_text, editorial_annotations ++ single_annotations}
  end

  defp extract_double_brackets(text) do
    pattern = ~r/\[\[([^\]]*)\]\]/

    annotations =
      Regex.scan(pattern, text)
      |> Enum.map(fn [_, content] ->
        %Annotation{type: :editorial, content: content}
      end)

    clean = Regex.replace(pattern, text, "")
    {clean, annotations}
  end

  defp extract_single_brackets(text) do
    # Match [...] but not line numbers (those have already been consumed by split_into_verses)
    pattern = ~r/\[([^\[\]]+)\]/

    matches = Regex.scan(pattern, text, return: :index)
    content_matches = Regex.scan(pattern, text)

    annotations =
      content_matches
      |> Enum.map(fn [_, content] -> classify_annotation(content) end)

    # Build clean text by removing all matched brackets
    clean =
      matches
      |> Enum.reverse()
      |> Enum.zip(Enum.reverse(content_matches))
      |> Enum.reduce(text, fn {[{start, len} | _], [_, content]}, acc ->
        annotation = classify_annotation(content)

        case annotation.type do
          :greek_gloss ->
            # Keep Greek glosses inline but styled
            String.slice(acc, 0, start) <> content <> String.slice(acc, (start + len)..-1//1)

          _ ->
            # Remove other annotations from the text
            String.slice(acc, 0, start) <> String.slice(acc, (start + len)..-1//1)
        end
      end)

    {clean, annotations}
  end

  @doc """
  Classify a bracket's content into an annotation type.
  """
  def classify_annotation(content) do
    content = String.trim(content)

    cond do
      # Variant reading: [n:v.l. ...]
      String.starts_with?(content, "n:v.l.") || String.starts_with?(content, "n: v.l.") ->
        variant_text = Regex.replace(~r/^n:\s*v\.l\.\s*/, content, "")
        %Annotation{type: :variant, content: variant_text}

      # Note with cross-ref: [n:=I-1.372] or [n:cf. I-1.28]
      Regex.match?(~r/^n:\s*=/, content) ->
        ref_text = Regex.replace(~r/^n:\s*=\s*/, content, "")
        refs = parse_cross_refs(ref_text)
        %Annotation{type: :cross_ref, content: ref_text, refs: refs}

      Regex.match?(~r/^n:\s*cf\./, content) ->
        ref_text = Regex.replace(~r/^n:\s*cf\.\s*/, content, "")
        refs = parse_cross_refs(ref_text)
        %Annotation{type: :cross_ref, content: "cf. " <> ref_text, refs: refs}

      # General note: [n:...]
      String.starts_with?(content, "n:") ->
        note_text = String.trim_leading(content, "n:")
        note_text = String.trim(note_text)
        # Check if note contains cross-refs
        refs = parse_cross_refs_from_note(note_text)
        %Annotation{type: :note, content: note_text, refs: refs}

      # Cross-reference: [=I-1.372] or [=I-1.101, I-2.76]
      String.starts_with?(content, "=") ->
        ref_text = String.trim_leading(content, "=")
        refs = parse_cross_refs(ref_text)
        %Annotation{type: :cross_ref, content: ref_text, refs: refs}

      # Editorial placeholders
      Regex.match?(~r/^(note needed|needs note|stopped here|check )/i, content) ->
        %Annotation{type: :editorial, content: content}

      # Greek gloss: contains > (macron marker) or is a known pattern
      Regex.match?(~r/^[a-zA-Z].*>/, content) || is_greek_gloss?(content) ->
        %Annotation{type: :greek_gloss, content: content}

      true ->
        # Default: treat as greek gloss if it looks like a word/phrase,
        # otherwise editorial
        if Regex.match?(~r/^[a-zA-Z][a-zA-Z\s>\.]+$/, content) do
          %Annotation{type: :greek_gloss, content: content}
        else
          %Annotation{type: :editorial, content: content}
        end
    end
  end

  defp is_greek_gloss?(content) do
    # Greek glosses are typically short, contain transliterated Greek words
    # with markers like >, pl., sg., etc.
    String.length(content) < 40 &&
      Regex.match?(~r/^[a-zA-Z>]+(\s+(pl\.|sg\.|acc\.|nom\.|gen\.|dat\.))?$/, content)
  end

  @doc """
  Parse cross-reference strings like "I-1.372" or "I-1.101, I-2.76" into
  a list of "book.line" strings.
  """
  def parse_cross_refs(text) do
    Regex.scan(~r/I-(\d+)\.(\d+[a-z]?)/, text)
    |> Enum.map(fn [_, book, line] -> "#{book}.#{line}" end)
  end

  defp parse_cross_refs_from_note(text) do
    # Extract any cross-refs embedded in note text
    parse_cross_refs(text)
  end

  defp collapse_whitespace(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/\s+,/, ",")
    |> String.trim()
  end
end
