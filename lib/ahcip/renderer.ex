defmodule AHCIP.Renderer do
  @moduledoc """
  Renders parsed book data into static HTML files using EEx templates.
  """

  require EEx

  alias AHCIP.{CrossRef, Annotation, CommentaryParser, WorkRegistry}

  @templates_dir Path.join([__DIR__, "..", "..", "templates"]) |> Path.expand()

  EEx.function_from_file(:def, :popover, Path.join([@templates_dir, "components", "popover.eex"]), [
    :assigns
  ])

  # Attribution strings for fallback translations
  @iliad_attribution "Translation by Samuel Butler, revised by Timothy Power and Gregory Nagy"
  @odyssey_attribution "Translation by Samuel Butler, revised by Timothy Power and Gregory Nagy"
  @hymn_attribution "Translation by Hugh G. Evelyn-White"

  @doc """
  Render the entire site: index page + all work/section pages.

  Expects a list of `{work, [{book, content}]}` tuples.
  """
  def render_site(works_with_content, output_dir) do
    File.mkdir_p!(output_dir)
    File.mkdir_p!(Path.join(output_dir, "css"))

    all_works = WorkRegistry.works()
    commentary_dir = Application.get_env(:ahcip, :commentary_dir, "commentary")
    all_comments = load_all_comments(commentary_dir)

    # Render index
    nav_groups = build_nav_groups(all_works, nil)
    work_groups = build_index_groups(works_with_content)
    index_html = render_index(nav_groups, work_groups)
    File.write!(Path.join(output_dir, "index.html"), index_html)

    # Render each work's sections
    for {work, sections_with_content} <- works_with_content do
      work_dir = Path.join([output_dir, "passages", work.slug])
      File.mkdir_p!(work_dir)

      for {book, content} <- sections_with_content do
        section_slug = "#{work.slug}/#{book.number}"
        nav_groups = build_nav_groups(all_works, section_slug)
        comments = get_comments_for_section(all_comments, work, book.number)
        display_title = AHCIP.ButlerFallback.display_title(book, work)
        attribution = fallback_attribution(work)

        section_html =
          render_section(book, content, nav_groups, comments, display_title, attribution)

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
    copy_css(output_dir)

    :ok
  end

  defp fallback_attribution(%{slug: "tlg0012.tlg001"}), do: @iliad_attribution
  defp fallback_attribution(%{slug: "tlg0012.tlg002"}), do: @odyssey_attribution
  defp fallback_attribution(%{section_type: :hymn}), do: @hymn_attribution
  defp fallback_attribution(_), do: ""

  defp build_nav_groups(works, current_slug) do
    # Group: Iliad, Odyssey, then all Hymns under one group
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
            for {book, _content} <- sections do
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
            for {book, _content} <- sections do
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

  @doc """
  Render the index page.
  """
  def render_index(nav_groups, work_groups) do
    nav =
      EEx.eval_file(
        Path.join(@templates_dir, "nav.eex"),
        assigns: [nav_groups: nav_groups]
      )

    content =
      EEx.eval_file(
        Path.join(@templates_dir, "index.eex"),
        assigns: [nav: nav, work_groups: work_groups]
      )

    render_layout("Home", content)
  end

  @doc """
  Render a single section page.
  """
  def render_section(book, content, nav_groups, comments, display_title, attribution) do
    nav =
      EEx.eval_file(
        Path.join(@templates_dir, "nav.eex"),
        assigns: [nav_groups: nav_groups]
      )

    book_content =
      EEx.eval_file(
        Path.join(@templates_dir, "book.eex"),
        assigns: [
          nav: nav,
          display_title: display_title,
          preamble: book.preamble,
          translators: book.translators,
          content: content,
          book_number: book.number,
          comments: comments,
          fallback_attribution: attribution
        ]
      )

    render_layout(display_title, book_content)
  end

  defp render_layout(title, content) do
    EEx.eval_file(
      Path.join(@templates_dir, "layout.eex"),
      assigns: [title: title, content: content]
    )
  end

  @doc """
  Load all comments from commentary directory, grouped by work and section.
  Returns %{"work:section" => [comment, ...]} sorted by start_line.
  """
  def load_all_comments(commentary_dir) do
    if File.dir?(commentary_dir) do
      CommentaryParser.load(commentary_dir)
      |> Enum.group_by(fn c -> "#{c["work"]}:#{c["book"]}" end)
      |> Enum.into(%{}, fn {key, comments} ->
        {key, Enum.sort_by(comments, & &1["start_line"])}
      end)
    else
      %{}
    end
  end

  defp get_comments_for_section(all_comments, work, section_number) do
    work_name =
      case work.slug do
        "tlg0012.tlg001" -> "iliad"
        "tlg0012.tlg002" -> "odyssey"
        slug when is_binary(slug) ->
          if String.starts_with?(slug, "tlg0013"), do: "hymn", else: nil
      end

    if work_name do
      Map.get(all_comments, "#{work_name}:#{section_number}", [])
    else
      []
    end
  end

  @doc """
  Render a line's text with inline Greek glosses styled and annotation popovers.
  """
  def render_line_text(line, _book_number) do
    text = smartquotes(line.text)

    # Style Greek glosses inline
    glosses =
      line.annotations
      |> Enum.filter(&(&1.type == :greek_gloss))
      |> Enum.map(& &1.content)

    text =
      Enum.reduce(glosses, text, fn gloss, acc ->
        String.replace(acc, gloss, ~s(<span class="greek-gloss">[#{escape_html(gloss)}]</span>),
          global: false
        )
      end)

    # Add cross-ref links
    cross_refs =
      line.annotations
      |> Enum.filter(&(&1.type == :cross_ref))

    ref_links =
      cross_refs
      |> Enum.flat_map(& &1.refs)
      |> Enum.map(&CrossRef.render_link/1)

    text =
      if length(ref_links) > 0 do
        text <> ~s( <span class="cross-refs">[) <> Enum.join(ref_links, ", ") <> "]</span>"
      else
        text
      end

    # Add inline annotation popovers for notes, variants, and editorial markers
    inline_annotations =
      line.annotations
      |> Enum.filter(&(&1.type in [:note, :variant, :editorial]))
      |> Enum.with_index(1)

    popover_html =
      Enum.map(inline_annotations, fn {ann, idx} ->
        superscript = integer_to_superscript(idx)
        type_label = note_type_label(ann.type)
        content = render_annotation_content(ann)

        popover(superscript: superscript, type_label: type_label, content: content)
      end)
      |> Enum.join("")

    macronize(text) <> popover_html
  end

  defp integer_to_superscript(n) do
    superscripts = %{
      ?0 => "\u2070",
      ?1 => "\u00B9",
      ?2 => "\u00B2",
      ?3 => "\u00B3",
      ?4 => "\u2074",
      ?5 => "\u2075",
      ?6 => "\u2076",
      ?7 => "\u2077",
      ?8 => "\u2078",
      ?9 => "\u2079"
    }

    n
    |> Integer.to_string()
    |> String.to_charlist()
    |> Enum.map(&Map.get(superscripts, &1, &1))
    |> List.to_string()
  end

  @doc """
  Return a display label for an annotation type.
  """
  def note_type_label(:note), do: "Note"
  def note_type_label(:variant), do: "Variant"
  def note_type_label(:editorial), do: "Editorial"
  def note_type_label(_), do: "Note"

  @doc """
  Render the content of an annotation for display in the commentary.
  """
  def render_annotation_content(%Annotation{type: :variant, content: content}) do
    ~s(<em>v.l.</em> #{escape_html(content)})
  end

  def render_annotation_content(%Annotation{content: content, refs: refs}) when refs != [] do
    ref_links =
      refs
      |> Enum.map(&CrossRef.render_link/1)
      |> Enum.join(", ")

    escape_html(content) <> " " <> ref_links
  end

  def render_annotation_content(%Annotation{content: content}) do
    escape_html(content)
  end

  def render_draftjs(%{"blocks" => blocks, "entityMap" => entity_map}) do
    blocks
    |> Enum.map(&render_draftjs_block(&1, entity_map))
    |> Enum.join("\n")
  end

  defp render_draftjs_block(%{"text" => text, "type" => type} = block, entity_map) do
    inline_styles = Map.get(block, "inlineStyleRanges", [])
    entity_ranges = Map.get(block, "entityRanges", [])

    rendered_text = apply_draftjs_formatting(text, inline_styles, entity_ranges, entity_map)

    case type do
      "blockquote" -> "<blockquote>#{rendered_text}</blockquote>"
      "header-two" -> "<h4>#{rendered_text}</h4>"
      _ -> "<p>#{rendered_text}</p>"
    end
  end

  defp apply_draftjs_formatting(text, inline_styles, entity_ranges, entity_map) do
    chars = String.graphemes(text)
    len = length(chars)

    if len == 0 do
      ""
    else
      # Build per-character style/entity tags
      {opens, closes} = build_formatting_tags(len, inline_styles, entity_ranges, entity_map)

      chars
      |> Enum.with_index()
      |> Enum.map(fn {char, i} ->
        open_tags = Map.get(opens, i, "")
        close_tags = Map.get(closes, i, "")
        open_tags <> escape_html(char) <> close_tags
      end)
      |> Enum.join()
    end
  end

  defp build_formatting_tags(len, inline_styles, entity_ranges, entity_map) do
    # Collect all ranges with their open/close tags
    ranges =
      Enum.map(inline_styles, fn %{"offset" => offset, "length" => length, "style" => style} ->
        tag = style_to_tag(style)
        {offset, offset + length, tag}
      end) ++
        Enum.flat_map(entity_ranges, fn %{"offset" => offset, "length" => length, "key" => key} ->
          entity = Map.get(entity_map, to_string(key), %{})
          entity_to_tags(entity, offset, length)
        end)

    # Build maps of open/close tags per character index
    Enum.reduce(ranges, {%{}, %{}}, fn {start, stop, {open, close}}, {opens, closes} ->
      stop = min(stop, len)
      start = min(start, len - 1)

      opens = Map.update(opens, start, open, &(&1 <> open))
      closes = Map.update(closes, stop - 1, close, &(close <> &1))
      {opens, closes}
    end)
  end

  defp style_to_tag("ITALIC"), do: {"<em>", "</em>"}
  defp style_to_tag("BOLD"), do: {"<strong>", "</strong>"}
  defp style_to_tag("UNDERLINE"), do: {"<u>", "</u>"}
  defp style_to_tag(_), do: {"", ""}

  defp entity_to_tags(%{"type" => "LINK", "data" => %{"url" => url}}, offset, length) do
    [{offset, offset + length, {~s(<a href="#{escape_html(url)}">), "</a>"}}]
  end

  defp entity_to_tags(%{"type" => "IMAGE", "data" => data}, offset, length) do
    src = escape_html(data["src"] || "")
    alt = escape_html(data["alt"] || "")
    [{offset, offset + length, {~s(<img src="#{src}" alt="#{alt}" loading="lazy">), ""}}]
  end

  defp entity_to_tags(_, _offset, _length), do: []

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp macronize(text) do
    text
    |> String.replace("e&gt;", "ē")
    |> String.replace("o&gt;", "ō")
  end

  @doc """
  Convert straight quotes and apostrophes to their curly/smart equivalents.
  """
  def smartquotes(text) do
    text
    # Apostrophes in contractions first (word'word)
    |> String.replace(~r/(\w)'(\w)/, "\\1\u2019\\2")
    # Double quotes via toggle (odd = open, even = close)
    |> replace_double_quotes()
    # Opening single quote after whitespace or start of string
    |> String.replace(~r/(^|\s)'/, "\\1\u2018")
    # Remaining single quotes → right single quote (closing/apostrophe)
    |> String.replace("'", "\u2019")
  end

  defp replace_double_quotes(text) do
    parts = String.split(text, "\"", parts: :infinity)

    {result, _} =
      Enum.reduce(parts, {"", true}, fn segment, {acc, is_open} ->
        if acc == "" do
          {segment, is_open}
        else
          quote_char = if is_open, do: "\u201C", else: "\u201D"
          {acc <> quote_char <> segment, !is_open}
        end
      end)

    result
  end

  defp copy_css(output_dir) do
    css_src = Path.join([__DIR__, "..", "..", "assets", "css", "style.css"]) |> Path.expand()

    if File.exists?(css_src) do
      File.cp!(css_src, Path.join(output_dir, "css/style.css"))
    end
  end
end
