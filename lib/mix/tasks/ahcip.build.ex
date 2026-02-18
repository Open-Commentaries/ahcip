defmodule Mix.Tasks.Ahcip.Build do
  @moduledoc """
  Builds the AHCIP static HTML site from scholar translations and TEI fallback texts.

  ## Usage

      mix ahcip.build

  Reads content from configured paths, parses, merges, and renders
  HTML output to the configured output directory.
  """

  use Mix.Task

  alias AHCIP.{WorkRegistry, Translations, GreekSource, FallbackMerge}
  alias Kodon.{TEIParser, Book, Renderer}

  @shortdoc "Build the AHCIP static site"

  # Attribution strings for fallback translations
  @iliad_attribution "Translation by Samuel Butler, revised by Timothy Power and Gregory Nagy"
  @odyssey_attribution "Translation by Samuel Butler, revised by Timothy Power and Gregory Nagy"
  @hymn_attribution "Translation by Hugh G. Evelyn-White"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    scholar_dir = Application.get_env(:kodon, :translation_dir)
    data_dir = fetch_required_env!(:data_dir)
    output_dir = Application.get_env(:kodon, :output_dir, "output")

    Mix.shell().info("Building AHCIP site...")
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
    render_site(works_with_content, output_dir)

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
      parsed = TEIParser.parse(tei_path)

      # Load Greek source text
      greek_data = load_greek_data(work, data_dir)

      # Build sections
      sections =
        case work.section_type do
          :book ->
            build_book_sections(work, parsed, scholar_dir, greek_data)

          :hymn ->
            build_hymn_sections(work, parsed, greek_data)
        end

      Mix.shell().info("  #{length(sections)} section(s)")
      {work, sections}
    end
  end

  defp build_book_sections(work, parsed, scholar_dir, greek_data) do
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

      content = FallbackMerge.merge(book, parsed, work.tei_format, section_num, render: true)
      greek_lines = Map.get(greek_data, section_num, %{})
      {book, content, greek_lines}
    end
  end

  defp build_hymn_sections(work, parsed, greek_data) do
    for section_num <- work.sections do
      book = %Book{
        number: section_num,
        title: work.title,
        translators: [],
        lines: [],
        work_slug: work.slug
      }

      content = FallbackMerge.merge(book, parsed, work.tei_format, section_num, render: true)
      greek_lines = Map.get(greek_data, section_num, %{})
      {book, content, greek_lines}
    end
  end

  defp parse_scholar_files(scholar_dir) do
    Translations.iliad_file_mapping()
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

  # --- Site rendering ---

  defp render_site(works_with_content, output_dir) do
    File.mkdir_p!(output_dir)

    all_works = WorkRegistry.works()
    commentary_dir = Application.get_env(:kodon, :commentary_dir, "commentary")
    all_comments = Renderer.load_all_comments(commentary_dir)

    # Render index
    nav_groups = build_nav_groups(all_works, nil)
    work_groups = build_index_groups(works_with_content)
    index_html = Renderer.render_index(nav_groups, work_groups)
    File.write!(Path.join(output_dir, "index.html"), index_html)

    # Render each work's sections
    for {work, sections_with_content} <- works_with_content do
      work_dir = Path.join([output_dir, "passages", work.slug])
      File.mkdir_p!(work_dir)

      for {book, content, greek_lines} <- sections_with_content do
        section_slug = "#{work.slug}/#{book.number}"
        nav_groups = build_nav_groups(all_works, section_slug)
        comments = get_comments_for_section(all_comments, work, book.number)
        display_title = FallbackMerge.display_title(book, work)
        attribution = fallback_attribution(work)

        section_html =
          Renderer.render_section(book, content, nav_groups, comments, display_title, attribution, greek_lines, work.scaife_url)

        filename =
          if work.section_type == :hymn do
            "index.html"
          else
            "#{book.number}.html"
          end

        File.write!(Path.join(work_dir, filename), section_html)
      end
    end

    # Copy CSS
    Renderer.copy_css(output_dir)

    :ok
  end

  defp fallback_attribution(%{slug: "tlg0012.tlg001"}), do: @iliad_attribution
  defp fallback_attribution(%{slug: "tlg0012.tlg002"}), do: @odyssey_attribution
  defp fallback_attribution(%{section_type: :hymn}), do: @hymn_attribution
  defp fallback_attribution(_), do: ""

  defp build_nav_groups(works, current_slug) do
    iliad = Enum.find(works, &(&1.slug == "tlg0012.tlg001"))
    odyssey = Enum.find(works, &(&1.slug == "tlg0012.tlg002"))
    hymns = Enum.filter(works, &(&1.section_type == :hymn))

    groups = []

    groups =
      if iliad do
        items =
          for n <- iliad.sections do
            slug = "#{iliad.slug}/#{n}"

            %{
              href: "/passages/#{iliad.slug}/#{n}.html",
              label: "#{iliad.section_label} #{n}",
              active: current_slug == slug,
              css_class: if(iliad.has_scholar_translations, do: "has-scholar", else: "butler-only")
            }
          end

        is_open = current_slug != nil && String.starts_with?(current_slug, iliad.slug)
        groups ++ [%{title: iliad.title, items: items, open: is_open}]
      else
        groups
      end

    groups =
      if odyssey do
        items =
          for n <- odyssey.sections do
            slug = "#{odyssey.slug}/#{n}"

            %{
              href: "/passages/#{odyssey.slug}/#{n}.html",
              label: "#{odyssey.section_label} #{n}",
              active: current_slug == slug,
              css_class: "butler-only"
            }
          end

        is_open = current_slug != nil && String.starts_with?(current_slug, odyssey.slug)
        groups ++ [%{title: odyssey.title, items: items, open: is_open}]
      else
        groups
      end

    if length(hymns) > 0 do
      items =
        for hymn <- hymns do
          slug = "#{hymn.slug}/1"

          %{
            href: "/passages/#{hymn.slug}/index.html",
            label: hymn.title,
            active: current_slug == slug,
            css_class: "butler-only"
          }
        end

      is_open = current_slug != nil && String.starts_with?(current_slug, "tlg0013")
      groups ++ [%{title: "Homeric Hymns", items: items, open: is_open}]
    else
      groups
    end
  end

  defp build_index_groups(works_with_content) do
    works_map =
      works_with_content
      |> Enum.map(fn {work, sections} -> {work.slug, {work, sections}} end)
      |> Enum.into(%{})

    groups = []

    # Iliad
    groups =
      case Map.get(works_map, "tlg0012.tlg001") do
        {work, sections} ->
          items =
            for {book, _content, _greek} <- sections do
              %{
                href: "/passages/#{work.slug}/#{book.number}.html",
                label: "#{work.section_label} #{book.number}",
                status:
                  if(length(book.lines) > 0,
                    do: "#{length(book.lines)} lines translated",
                    else: "Butler translation"
                  ),
                css_class:
                  if(length(book.lines) > 0, do: "has-scholar", else: "butler-only")
              }
            end

          groups ++
            [
              %{
                title: "The Iliad",
                subtitle:
                  "Translated by Casey Due, Mary Ebbott, Douglas Frame, Leonard Muellner, and Gregory Nagy",
                items: items
              }
            ]

        nil ->
          groups
      end

    # Odyssey
    groups =
      case Map.get(works_map, "tlg0012.tlg002") do
        {work, sections} ->
          items =
            for {book, _content, _greek} <- sections do
              %{
                href: "/passages/#{work.slug}/#{book.number}.html",
                label: "#{work.section_label} #{book.number}",
                status: "Butler/Power/Nagy translation",
                css_class: "butler-only"
              }
            end

          groups ++
            [
              %{
                title: "The Odyssey",
                subtitle:
                  "Translation by Samuel Butler, revised by Timothy Power and Gregory Nagy",
                items: items
              }
            ]

        nil ->
          groups
      end

    # Homeric Hymns
    hymn_works =
      works_with_content
      |> Enum.filter(fn {work, _} -> work.section_type == :hymn end)
      |> Enum.sort_by(fn {work, _} -> work.slug end)

    if length(hymn_works) > 0 do
      items =
        for {work, _sections} <- hymn_works do
          %{
            href: "/passages/#{work.slug}/index.html",
            label: work.title,
            status: "Evelyn-White translation",
            css_class: "butler-only"
          }
        end

      groups ++
        [
          %{
            title: "Homeric Hymns",
            subtitle: "Translation by Hugh G. Evelyn-White",
            items: items
          }
        ]
    else
      groups
    end
  end

  defp get_comments_for_section(all_comments, work, section_number) do
    {work_name, comment_book} =
      case work.slug do
        "tlg0012.tlg001" -> {"iliad", section_number}
        "tlg0012.tlg002" -> {"odyssey", section_number}
        "tlg0013.tlg" <> padded_num -> {"hymn", String.to_integer(padded_num)}
        _ -> {nil, nil}
      end

    if work_name do
      Map.get(all_comments, "#{work_name}:#{comment_book}", [])
    else
      []
    end
  end

  defp fetch_required_env!(key) do
    case Application.get_env(:kodon, key) do
      nil -> Mix.raise("Missing required config: config :kodon, #{key}: \"path/to/dir\"")
      value -> value
    end
  end

  defp load_greek_data(work, data_dir) do
    greek_rel_path = GreekSource.greek_path(work.tei_path)
    greek_abs_path = Path.join(data_dir, greek_rel_path)

    if File.exists?(greek_abs_path) do
      Mix.shell().info("  Loading Greek source: #{greek_rel_path}")

      case work.section_type do
        :book -> GreekSource.parse_books(greek_abs_path)
        :hymn -> GreekSource.parse_hymn(greek_abs_path)
      end
    else
      Mix.shell().info("  Greek source not found: #{greek_rel_path}")
      %{}
    end
  end

  defp report_stats(works_with_content) do
    for {work, sections} <- works_with_content do
      total_lines =
        sections
        |> Enum.map(fn {book, _, _} -> length(book.lines) end)
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
