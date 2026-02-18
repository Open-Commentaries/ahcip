defmodule AHCIP.FallbackMergeTest do
  use ExUnit.Case, async: true

  alias AHCIP.FallbackMerge
  alias Kodon.{Book, Line, TEIParser}

  @fixtures_dir Path.expand("../fixtures", __DIR__)

  defp make_line(number) do
    num_str = to_string(number)

    %Line{
      number: num_str,
      sort_key: Line.sort_key(num_str),
      text: "Scholar line #{number}",
      raw_text: "Scholar line #{number}",
      annotations: []
    }
  end

  # --- book_card_milestone format ---

  describe "merge/5 with book_card_milestone format" do
    setup do
      parsed = TEIParser.parse(Path.join(@fixtures_dir, "tei_book_card_milestone.xml"))
      %{parsed: parsed}
    end

    test "entirely untranslated book returns full fallback gap", %{parsed: parsed} do
      book = %Book{number: 1, title: nil, translators: [], lines: []}
      items = FallbackMerge.merge(book, parsed, :book_card_milestone, 1)

      assert [{:fallback_gap, gap}] = items
      assert gap.start_line == 1
      assert gap.end_line == 10
      assert length(gap.elements) > 0
    end

    test "fully translated book has no internal gaps", %{parsed: parsed} do
      lines = Enum.map(1..10, &make_line/1)
      book = %Book{number: 1, title: "Test", translators: [], lines: lines}
      items = FallbackMerge.merge(book, parsed, :book_card_milestone, 1)

      scholar_items = Enum.filter(items, fn {type, _} -> type == :scholar_line end)

      internal_gaps =
        Enum.filter(items, fn
          {:fallback_gap, g} -> g.start_line > 1 && g.start_line < 10
          _ -> false
        end)

      assert length(scholar_items) == 10
      assert length(internal_gaps) == 0
    end

    test "partial translation creates gaps", %{parsed: parsed} do
      # Scholar has lines 5-8 only
      lines = Enum.map(5..8, &make_line/1)
      book = %Book{number: 1, title: "Test", translators: [], lines: lines}
      items = FallbackMerge.merge(book, parsed, :book_card_milestone, 1)

      scholar_items = Enum.filter(items, fn {type, _} -> type == :scholar_line end)
      gap_items = Enum.filter(items, fn {type, _} -> type == :fallback_gap end)

      assert length(scholar_items) == 4
      # Should have gaps: before line 5 (1-4), after line 8 (9-10)
      assert length(gap_items) >= 1

      # First gap should start at line 1
      first_gap = Enum.at(gap_items, 0) |> elem(1)
      assert first_gap.start_line == 1
      assert first_gap.end_line == 4
    end

    test "render option pre-renders gap HTML", %{parsed: parsed} do
      book = %Book{number: 1, title: nil, translators: [], lines: []}
      items = FallbackMerge.merge(book, parsed, :book_card_milestone, 1, render: true)

      [{:fallback_gap, gap}] = items
      assert gap.rendered_html != nil
      assert is_binary(gap.rendered_html)
      assert gap.rendered_html =~ "Sing, O goddess"
    end

    test "different book number extracts different content", %{parsed: parsed} do
      book = %Book{number: 2, title: nil, translators: [], lines: []}
      items = FallbackMerge.merge(book, parsed, :book_card_milestone, 2, render: true)

      [{:fallback_gap, gap}] = items
      assert gap.rendered_html =~ "rest of the gods"
    end
  end

  # --- line_elements format ---

  describe "merge/5 with line_elements format" do
    setup do
      parsed = TEIParser.parse(Path.join(@fixtures_dir, "tei_line_elements.xml"))
      %{parsed: parsed}
    end

    test "entirely untranslated hymn returns full fallback gap", %{parsed: parsed} do
      book = %Book{number: 1, title: "To Dionysus", translators: [], lines: []}
      items = FallbackMerge.merge(book, parsed, :line_elements, 1)

      assert [{:fallback_gap, gap}] = items
      assert gap.start_line == 1
      assert gap.end_line == 3
      assert length(gap.elements) == 3
    end

    test "render option pre-renders line elements", %{parsed: parsed} do
      book = %Book{number: 1, title: "To Dionysus", translators: [], lines: []}
      items = FallbackMerge.merge(book, parsed, :line_elements, 1, render: true)

      [{:fallback_gap, gap}] = items
      assert gap.rendered_html != nil
      assert gap.rendered_html =~ "Dionysus"
    end
  end

  # --- display_title ---

  describe "display_title/2" do
    test "uses scholar title when available" do
      assert FallbackMerge.display_title(%Book{number: 1, title: "SCROLL I-1"}) == "SCROLL I-1"
    end

    test "falls back to work section label" do
      work = %{section_label: "Scroll", section_type: :book, slug: "test"}
      assert FallbackMerge.display_title(%Book{number: 6, title: nil}, work) == "Scroll 6"
    end

    test "uses hymn title for hymns" do
      work = %{title: "To Dionysus", section_type: :hymn, slug: "test"}
      assert FallbackMerge.display_title(%Book{number: 1, title: nil}, work) == "To Dionysus"
    end

    test "falls back to Scroll N with no work" do
      assert FallbackMerge.display_title(%Book{number: 6, title: nil}) == "Scroll 6"
    end
  end
end
