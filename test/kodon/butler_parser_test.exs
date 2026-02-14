defmodule Kodon.ButlerParserTest do
  use ExUnit.Case, async: true

  @butler_path "/Users/pletcher/code/PerseusDL/canonical-greekLit/data/tlg0012/tlg001/tlg0012.tlg001.perseus-eng4.xml"

  setup_all do
    if File.exists?(@butler_path) do
      {:ok, butler: Kodon.ButlerParser.parse_file(@butler_path)}
    else
      {:ok, butler: nil}
    end
  end

  @tag :integration
  test "parses all 24 books", %{butler: butler} do
    if butler do
      assert map_size(butler) == 24

      for book_num <- 1..24 do
        assert Map.has_key?(butler, book_num), "Missing book #{book_num}"
        assert length(butler[book_num]) > 0, "Book #{book_num} has no segments"
      end
    end
  end

  @tag :integration
  test "Book 1 starts with 'Sing, O goddess'", %{butler: butler} do
    if butler do
      first = List.first(butler[1])
      assert first.start_line == 1
      assert first.text =~ "Sing, O goddess"
    end
  end

  @tag :integration
  test "lookup returns text for a line range", %{butler: butler} do
    if butler do
      text = Kodon.ButlerParser.lookup(butler, 1, 1, 5)
      assert text =~ "Sing, O goddess"
      assert text =~ "anger"
    end
  end

  @tag :integration
  test "lookup returns empty string for nonexistent book", %{butler: butler} do
    if butler do
      assert Kodon.ButlerParser.lookup(butler, 99, 1, 10) == ""
    end
  end

  @tag :integration
  test "segments are sorted by start_line", %{butler: butler} do
    if butler do
      for {_book_num, segments} <- butler do
        lines = Enum.map(segments, & &1.start_line)
        assert lines == Enum.sort(lines)
      end
    end
  end
end
