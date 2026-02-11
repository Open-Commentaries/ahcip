defmodule Mix.Tasks.Ahcip.Build do
  @moduledoc """
  Builds the static HTML site from scholar translations and Butler fallback.

  ## Usage

      mix ahcip.build

  Reads content from configured paths, parses, merges, and renders
  HTML output to the configured output directory.
  """

  use Mix.Task

  @shortdoc "Build the AHCIP static site"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    scholar_dir = Application.get_env(:ahcip, :scholar_content_dir)
    butler_path = Application.get_env(:ahcip, :butler_xml_path)
    output_dir = Application.get_env(:ahcip, :output_dir)

    Mix.shell().info("Building AHCIP site...")
    Mix.shell().info("  Scholar content: #{scholar_dir}")
    Mix.shell().info("  Butler XML: #{butler_path}")
    Mix.shell().info("  Output: #{output_dir}")
    Mix.shell().info("")

    # Step 1: Parse scholar translations
    Mix.shell().info("Parsing scholar translations...")
    scholar_books = parse_scholar_files(scholar_dir)
    Mix.shell().info("  Parsed #{length(scholar_books)} scholar files")

    # Step 2: Parse Butler XML
    Mix.shell().info("Parsing Butler XML...")
    butler_data = AHCIP.ButlerParser.parse_file(butler_path)
    Mix.shell().info("  Parsed #{map_size(butler_data)} books from Butler")

    # Step 3: Create book entries for all 24 books (including Butler-only)
    Mix.shell().info("Merging content...")
    all_books = build_all_books(scholar_books, butler_data)

    # Step 4: Render site
    Mix.shell().info("Rendering HTML...")
    AHCIP.Renderer.render_site(all_books, output_dir)

    # Report
    Mix.shell().info("")
    Mix.shell().info("Build complete!")
    report_stats(all_books)
  end

  defp parse_scholar_files(scholar_dir) do
    AHCIP.file_mapping()
    |> Enum.map(fn {filename, _book_num} ->
      path = Path.join(scholar_dir, filename)

      if File.exists?(path) do
        AHCIP.Parser.parse_file(path)
      else
        Mix.shell().info("  WARNING: #{filename} not found, skipping")
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp build_all_books(scholar_books, butler_data) do
    scholar_by_number =
      scholar_books
      |> Enum.map(fn book -> {book.number, book} end)
      |> Enum.into(%{})

    for book_num <- 1..24 do
      book =
        case Map.get(scholar_by_number, book_num) do
          nil ->
            # Butler-only book
            %AHCIP.Book{
              number: book_num,
              title: nil,
              translators: [],
              lines: []
            }

          scholar_book ->
            scholar_book
        end

      content = AHCIP.ButlerFallback.merge(book, butler_data)
      {book, content}
    end
  end

  defp report_stats(all_books) do
    total_scholar_lines =
      all_books
      |> Enum.map(fn {book, _} -> length(book.lines) end)
      |> Enum.sum()

    scholar_count =
      all_books
      |> Enum.count(fn {book, _} -> length(book.lines) > 0 end)

    butler_only =
      all_books
      |> Enum.count(fn {book, _} -> length(book.lines) == 0 end)

    Mix.shell().info("  Scholar translations: #{scholar_count} books, #{total_scholar_lines} lines")
    Mix.shell().info("  Butler-only books: #{butler_only}")
    Mix.shell().info("  Total books: #{length(all_books)}")
    Mix.shell().info("  Output files: #{length(all_books) + 1} HTML pages + CSS")
  end
end
