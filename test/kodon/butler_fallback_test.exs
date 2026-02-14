defmodule Kodon.ButlerFallbackTest do
  use ExUnit.Case, async: true

  alias Kodon.{Book, Line, ButlerFallback}

  # Simple mock butler data for testing
  defp mock_butler do
    %{
      1 => [
        %{start_line: 1, text: "Butler line 1-4"},
        %{start_line: 5, text: "Butler line 5-9"},
        %{start_line: 10, text: "Butler line 10-14"},
        %{start_line: 15, text: "Butler line 15-19"},
        %{start_line: 20, text: "Butler line 20-24"}
      ],
      6 => [
        %{start_line: 1, text: "Butler Book 6 text"}
      ]
    }
  end

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

  test "entirely untranslated book returns full Butler gap" do
    book = %Book{number: 6, title: nil, translators: [], lines: []}
    items = ButlerFallback.merge(book, mock_butler())

    assert [{:butler_gap, gap}] = items
    assert gap.start_line == 1
    assert gap.butler_text =~ "Butler Book 6"
  end

  test "fully translated book has no internal gaps" do
    lines = Enum.map(1..20, &make_line/1)
    book = %Book{number: 1, title: "Test", translators: [], lines: lines}
    items = ButlerFallback.merge(book, mock_butler())

    scholar_items = Enum.filter(items, fn {type, _} -> type == :scholar_line end)

    internal_gaps =
      Enum.filter(items, fn
        {:butler_gap, g} -> g.start_line > 1 && g.start_line < 20
        _ -> false
      end)

    assert length(scholar_items) == 20
    assert length(internal_gaps) == 0
  end

  test "partial translation creates gaps" do
    # Scholar has lines 5-10 only
    lines = Enum.map(5..10, &make_line/1)
    book = %Book{number: 1, title: "Test", translators: [], lines: lines}
    items = ButlerFallback.merge(book, mock_butler())

    scholar_items = Enum.filter(items, fn {type, _} -> type == :scholar_line end)
    gap_items = Enum.filter(items, fn {type, _} -> type == :butler_gap end)

    assert length(scholar_items) == 6
    # Should have gaps: before line 5, after line 10
    assert length(gap_items) >= 1

    # First gap should be lines 1-4
    first_gap = Enum.at(gap_items, 0) |> elem(1)
    assert first_gap.start_line == 1
    assert first_gap.end_line == 4
  end

  test "non-contiguous lines create internal gaps" do
    # Scholar has lines 1-3 and 10-12
    lines = Enum.map(1..3, &make_line/1) ++ Enum.map(10..12, &make_line/1)
    book = %Book{number: 1, title: "Test", translators: [], lines: lines}
    items = ButlerFallback.merge(book, mock_butler())

    gap_items = Enum.filter(items, fn {type, _} -> type == :butler_gap end)

    # Should have gap between 3 and 10 (lines 4-9)
    internal_gap =
      Enum.find(gap_items, fn {:butler_gap, g} -> g.start_line == 4 end)

    assert internal_gap
    {:butler_gap, gap} = internal_gap
    assert gap.end_line == 9
  end

  test "display_title uses scholar title when available" do
    assert ButlerFallback.display_title(%Book{number: 1, title: "SCROLL I-1"}) == "SCROLL I-1"
  end

  test "display_title falls back to Scroll N" do
    assert ButlerFallback.display_title(%Book{number: 6, title: nil}) == "Scroll 6"
  end
end
