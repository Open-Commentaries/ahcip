defmodule Mix.Tasks.Kodon.Build do
  @moduledoc """
  Builds the static HTML site from scholar translations and TEI fallback texts.

  ## Usage

      mix kodon.build

  Reads content from configured paths, parses, merges, and renders
  HTML output to the configured output directory.
  """

  use Mix.Task

  alias Kodon.{WorkRegistry, TEIParser, ButlerFallback, Book}

  @shortdoc "Build the Kodon static site"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    scholar_dir = Application.get_env(:kodon, :translation_dir)
    data_dir = Application.get_env(:kodon, :data_dir)
    output_dir = Application.get_env(:kodon, :output_dir)

    Mix.shell().info("Building Kodon site...")
    Mix.shell().info("  Scholar content: #{scholar_dir}")
    Mix.shell().info("  TEI data dir: #{data_dir}")
    Mix.shell().info("  Output: #{output_dir}")
    Mix.shell().info("")

    works_with_content =
      WorkRegistry.works()
      |> Enum.map(fn work -> build_work(work, data_dir, scholar_dir) end)
      |> Enum.reject(&is_nil/1)

    # Render site
    Mix.shell().info("Rendering HTML...")
    Kodon.Renderer.render_site(works_with_content, output_dir)

    # Report
    Mix.shell().info("")
    Mix.shell().info("Build complete!")
    report_stats(works_with_content)
  end

  defp build_work(work, data_dir, scholar_dir) do
    tei_path = Path.join(data_dir, work.tei_path)

    unless File.exists?(tei_path) do
      Mix.shell().info("  Skipping #{work.title}: TEI file not found at #{tei_path}")
      nil
    else
      Mix.shell().info("Processing #{work.title}...")

      # Parse TEI
      tei_data = TEIParser.parse_file(tei_path, work.tei_format)

      # Build sections
      sections =
        case work.section_type do
          :book ->
            build_book_sections(work, tei_data, scholar_dir)

          :hymn ->
            build_hymn_sections(work, tei_data)
        end

      Mix.shell().info("  #{length(sections)} section(s)")
      {work, sections}
    end
  end

  defp build_book_sections(work, tei_data, scholar_dir) do
    # For the Iliad, merge with scholar translations
    scholar_by_number =
      if work.has_scholar_translations do
        parse_scholar_files(scholar_dir)
        |> Enum.map(fn book -> {book.number, book} end)
        |> Enum.into(%{})
      else
        %{}
      end

    for section_num <- work.sections do
      book =
        case Map.get(scholar_by_number, section_num) do
          nil ->
            %Book{
              number: section_num,
              title: nil,
              translators: [],
              lines: [],
              work_slug: work.slug
            }

          scholar_book ->
            %{scholar_book | work_slug: work.slug}
        end

      content = ButlerFallback.merge(book, tei_data)
      {book, content}
    end
  end

  defp build_hymn_sections(work, tei_data) do
    # Hymns have a single section with all lines as a butler_gap
    # (no scholar translations)
    title =
      case tei_data do
        %{title: t} when is_binary(t) -> t
        _ -> work.title
      end

    sections_data =
      case tei_data do
        %{sections: s} -> s
        _ -> tei_data
      end

    for section_num <- work.sections do
      book = %Book{
        number: section_num,
        title: title,
        translators: [],
        lines: [],
        work_slug: work.slug
      }

      content = ButlerFallback.merge(book, sections_data)
      {book, content}
    end
  end

  defp parse_scholar_files(scholar_dir) do
    Kodon.iliad_file_mapping()
    |> Enum.map(fn {filename, _book_num} ->
      path = Path.join(scholar_dir, filename)

      if File.exists?(path) do
        Kodon.Parser.parse_file(path)
      else
        Mix.shell().info("  WARNING: #{filename} not found, skipping")
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp report_stats(works_with_content) do
    for {work, sections} <- works_with_content do
      total_lines =
        sections
        |> Enum.map(fn {book, _} -> length(book.lines) end)
        |> Enum.sum()

      Mix.shell().info(
        "  #{work.title}: #{length(sections)} sections, #{total_lines} scholar lines"
      )
    end

    total_pages =
      works_with_content
      |> Enum.map(fn {_, sections} -> length(sections) end)
      |> Enum.sum()

    Mix.shell().info("  Total: #{total_pages} pages + index + CSS")
  end
end
