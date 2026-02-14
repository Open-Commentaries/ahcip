defmodule Kodon.ParserTest do
  use ExUnit.Case, async: true

  alias Kodon.{Parser, Line, Annotation}

  @fixtures_dir Path.join([__DIR__, "..", "fixtures"]) |> Path.expand()

  describe "preprocess/1" do
    test "strips BOM" do
      assert Parser.preprocess(<<0xEF, 0xBB, 0xBF>> <> "hello") == "hello"
    end

    test "normalizes smart quotes" do
      assert Parser.preprocess("\u2018hello\u2019") == "'hello'"
      assert Parser.preprocess("\u201Chello\u201D") == "\"hello\""
    end

    test "normalizes dashes" do
      assert Parser.preprocess("word\u2013word") == "word--word"
      assert Parser.preprocess("word\u2014word") == "word--word"
    end
  end

  describe "extract_header/1" do
    test "parses Book 1 header with preamble" do
      content = Parser.preprocess(File.read!(Path.join(@fixtures_dir, "book_01_excerpt.txt")))
      {preamble, title, translators, body} = Parser.extract_header(content)

      assert preamble =~ "Translators' Introduction:"
      assert title == "SCROLL I-1"
      assert "Casey Due" in translators
      assert "Gregory Nagy" in translators
      assert length(translators) == 5
      assert String.starts_with?(body, "[1]")
    end

    test "parses Book 3 header with BOM and 'Iliad Scroll' title" do
      content = Parser.preprocess(File.read!(Path.join(@fixtures_dir, "book_03_excerpt.txt")))
      {preamble, title, translators, body} = Parser.extract_header(content)

      assert preamble == nil
      assert title == "Iliad Scroll 3"
      assert length(translators) == 5
      assert String.starts_with?(body, "[1]")
    end

    test "parses Book 2 header with 'Iliad N' title" do
      content = Parser.preprocess(File.read!(Path.join(@fixtures_dir, "book_02_excerpt.txt")))
      {preamble, title, translators, body} = Parser.extract_header(content)

      assert preamble == nil
      assert title == "Iliad 2"
      assert length(translators) == 5
      assert String.starts_with?(body, "[1]")
    end

    test "parses Book 15 header with single translator" do
      content = Parser.preprocess(File.read!(Path.join(@fixtures_dir, "book_15_excerpt.txt")))
      {preamble, title, translators, body} = Parser.extract_header(content)

      assert preamble == nil
      assert title == "Iliad 15"
      assert translators == ["Douglas Frame"]
      assert String.starts_with?(body, "[401]")
    end
  end

  describe "extract_book_number/2" do
    test "extracts from SCROLL I-N format" do
      assert Parser.extract_book_number("SCROLL I-1", "test.txt") == 1
      assert Parser.extract_book_number("SCROLL I-4", "test.txt") == 4
    end

    test "extracts from Iliad Scroll N format" do
      assert Parser.extract_book_number("Iliad Scroll 3", "test.txt") == 3
    end

    test "extracts from Iliad N format" do
      assert Parser.extract_book_number("Iliad 15", "test.txt") == 15
    end

    test "falls back to filename" do
      assert Parser.extract_book_number(nil, "Iliad 22.txt") == 22
    end
  end

  describe "split_into_verses/1" do
    test "splits single long line into verses" do
      body = "[1] First line text [2] Second line text [3] Third line"
      verses = Parser.split_into_verses(body)

      assert length(verses) == 3
      assert {"1", "First line text"} = Enum.at(verses, 0)
      assert {"2", "Second line text"} = Enum.at(verses, 1)
      assert {"3", "Third line"} = Enum.at(verses, 2)
    end

    test "splits line-per-verse format" do
      body = "[484] Tell me now, Muses\n[485] for you are goddesses\n[486] whereas we only hear"
      verses = Parser.split_into_verses(body)

      assert length(verses) == 3
      assert {"484", text} = Enum.at(verses, 0)
      assert text =~ "Tell me now"
    end

    test "handles sub-line numbers like 40a" do
      body = "[40] I would prefer it [40a] and that you never had a dear son"
      verses = Parser.split_into_verses(body)

      assert length(verses) == 2
      assert {"40", _} = Enum.at(verses, 0)
      assert {"40a", _} = Enum.at(verses, 1)
    end

    test "does not split on annotation brackets" do
      body = "[1] The anger [me>nis] of Peleus [n:commentary here] son [=I-1.372]"
      verses = Parser.split_into_verses(body)

      assert length(verses) == 1
      {_, text} = Enum.at(verses, 0)
      assert text =~ "me>nis"
      assert text =~ "n:commentary"
      assert text =~ "=I-1.372"
    end

    test "handles non-contiguous line numbers" do
      body = "[1] First [2] Second [3] Third [484] Much later"
      verses = Parser.split_into_verses(body)

      assert length(verses) == 4
      assert {"484", _} = Enum.at(verses, 3)
    end

    test "handles zero-padded line numbers" do
      body = "[001] First line [002] Second line"
      verses = Parser.split_into_verses(body)

      assert length(verses) == 2
      assert {"001", _} = Enum.at(verses, 0)
    end
  end

  describe "classify_annotation/1" do
    test "identifies Greek glosses" do
      assert %Annotation{type: :greek_gloss, content: "me>nis"} =
               Parser.classify_annotation("me>nis")

      assert %Annotation{type: :greek_gloss, content: "algos pl."} =
               Parser.classify_annotation("algos pl.")

      assert %Annotation{type: :greek_gloss, content: "psukhe> pl."} =
               Parser.classify_annotation("psukhe> pl.")
    end

    test "identifies notes" do
      ann = Parser.classify_annotation("n:Chryse>s is the name of the man")
      assert ann.type == :note
      assert ann.content == "Chryse>s is the name of the man"
    end

    test "identifies variant readings" do
      ann = Parser.classify_annotation("n:v.l. heads")
      assert ann.type == :variant
      assert ann.content == "heads"
    end

    test "identifies variant readings with extra space" do
      ann = Parser.classify_annotation("n: v.l. a feast for birds")
      assert ann.type == :variant
      assert ann.content == "a feast for birds"
    end

    test "identifies cross-references" do
      ann = Parser.classify_annotation("=I-1.372")
      assert ann.type == :cross_ref
      assert ann.refs == ["1.372"]
    end

    test "identifies multiple cross-references" do
      ann = Parser.classify_annotation("=I-1.101, I-2.76, I-7.354")
      assert ann.type == :cross_ref
      assert ann.refs == ["1.101", "2.76", "7.354"]
    end

    test "identifies note cross-references" do
      ann = Parser.classify_annotation("n:=I-1.372")
      assert ann.type == :cross_ref
      assert ann.refs == ["1.372"]
    end

    test "identifies cf. cross-references" do
      ann = Parser.classify_annotation("n:cf. I-1.28")
      assert ann.type == :cross_ref
      assert "1.28" in ann.refs
    end

    test "identifies editorial placeholders" do
      assert %Annotation{type: :editorial} =
               Parser.classify_annotation("note needed about body vs. soul")

      assert %Annotation{type: :editorial} = Parser.classify_annotation("needs note")
      assert %Annotation{type: :editorial} = Parser.classify_annotation("stopped here 2/24/06")

      assert %Annotation{type: :editorial} =
               Parser.classify_annotation("check peitho-s in book 1")
    end
  end

  describe "extract_annotations/1" do
    test "extracts Greek glosses keeping them in clean text" do
      {clean, annotations} = Parser.extract_annotations("The anger [me>nis] of Peleus")

      assert clean =~ "me>nis"
      assert Enum.any?(annotations, &(&1.type == :greek_gloss))
    end

    test "removes notes from clean text" do
      {clean, annotations} = Parser.extract_annotations("text [n:some note] more text")

      refute clean =~ "n:some note"
      assert clean =~ "text"
      assert clean =~ "more text"
      assert Enum.any?(annotations, &(&1.type == :note))
    end

    test "removes cross-refs from clean text" do
      {clean, annotations} = Parser.extract_annotations("text [=I-1.372] more")

      refute clean =~ "=I-1.372"
      assert Enum.any?(annotations, &(&1.type == :cross_ref))
    end

    test "handles double-bracket editorial markers" do
      {clean, annotations} = Parser.extract_annotations("text [[editorial comment]] more")

      refute clean =~ "editorial comment"
      assert Enum.any?(annotations, &(&1.type == :editorial && &1.content == "editorial comment"))
    end

    test "handles multiple annotation types in one line" do
      text = "The anger [me>nis] disastrous [n:v.l. heads] [=I-1.372]"
      {_clean, annotations} = Parser.extract_annotations(text)

      types = Enum.map(annotations, & &1.type) |> MapSet.new()
      assert :greek_gloss in types
      assert :variant in types
      assert :cross_ref in types
    end
  end

  describe "parse_verse_line/1" do
    test "produces Line struct with clean text and annotations" do
      line =
        Parser.parse_verse_line(
          {"1", "The anger [me>nis] of Peleus' son Achilles, goddess, perform its song --"}
        )

      assert %Line{} = line
      assert line.number == "1"
      assert line.sort_key == {1, ""}
      assert line.text =~ "anger"
      assert line.text =~ "me>nis"
      assert Enum.any?(line.annotations, &(&1.type == :greek_gloss))
    end

    test "handles sub-line sort keys" do
      line = Parser.parse_verse_line({"40a", "some text"})
      assert line.sort_key == {40, "a"}
    end
  end

  describe "parse_file/1" do
    test "parses Book 1 excerpt" do
      book = Parser.parse_file(Path.join(@fixtures_dir, "book_01_excerpt.txt"))

      assert %Kodon.Book{} = book
      assert book.number == 1
      assert book.title == "SCROLL I-1"
      assert length(book.translators) == 5
      assert book.preamble =~ "Translators' Introduction"
      assert length(book.lines) == 14

      # First line
      first = Enum.at(book.lines, 0)
      assert first.number == "1"
      assert first.text =~ "anger"
      assert first.text =~ "me>nis"

      # Line with cross-ref
      line_13 = Enum.find(book.lines, &(&1.number == "13"))
      assert line_13
      cross_refs = Enum.filter(line_13.annotations, &(&1.type == :cross_ref))
      assert length(cross_refs) > 0
      assert "1.372" in List.first(cross_refs).refs
    end

    test "parses Book 3 excerpt with BOM and sub-lines" do
      book = Parser.parse_file(Path.join(@fixtures_dir, "book_03_excerpt.txt"))

      assert book.number == 3
      assert book.title == "Iliad Scroll 3"

      # Should have line 40a
      line_40a = Enum.find(book.lines, &(&1.number == "40a"))
      assert line_40a
      assert line_40a.sort_key == {40, "a"}
    end

    test "parses Book 2 excerpt with hybrid format" do
      book = Parser.parse_file(Path.join(@fixtures_dir, "book_02_excerpt.txt"))

      assert book.number == 2
      # Should have both early lines (1-3) and later lines (484-486)
      numbers = Enum.map(book.lines, & &1.number)
      assert "1" in numbers
      assert "3" in numbers
      assert "484" in numbers
      assert "486" in numbers
    end

    test "parses Book 15 excerpt with single translator" do
      book = Parser.parse_file(Path.join(@fixtures_dir, "book_15_excerpt.txt"))

      assert book.number == 15
      assert book.translators == ["Douglas Frame"]
      assert length(book.lines) == 4

      # Line 404 has a cross-ref [=I-11.793]
      line_404 = Enum.find(book.lines, &(&1.number == "404"))
      assert line_404
      cross_refs = Enum.filter(line_404.annotations, &(&1.type == :cross_ref))
      assert length(cross_refs) > 0
    end
  end

  describe "Line.sort_key/1" do
    test "simple numbers" do
      assert Line.sort_key("1") == {1, ""}
      assert Line.sort_key("100") == {100, ""}
      assert Line.sort_key("001") == {1, ""}
    end

    test "sub-line numbers" do
      assert Line.sort_key("40a") == {40, "a"}
      assert Line.sort_key("302a") == {302, "a"}
    end

    test "variant line numbers" do
      assert Line.sort_key("302 v.l.") == {302, "v.l."}
    end

    test "sort order" do
      keys = ["40a", "40", "41", "39"] |> Enum.map(&Line.sort_key/1) |> Enum.sort()
      assert keys == [{39, ""}, {40, ""}, {40, "a"}, {41, ""}]
    end
  end
end
