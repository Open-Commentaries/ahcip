defmodule AHCIP.Renderer do
  @moduledoc """
  Renders parsed book data into static HTML files using EEx templates.
  """

  require EEx

  alias AHCIP.{CrossRef, Annotation, CommentaryParser}

  @templates_dir Path.join([__DIR__, "..", "..", "templates"]) |> Path.expand()

  EEx.function_from_file(:def, :popover, Path.join([@templates_dir, "components", "popover.eex"]), [
    :assigns
  ])

  @doc """
  Render the entire site: index page + all book pages.
  """
  def render_site(books_with_content, output_dir) do
    File.mkdir_p!(output_dir)
    File.mkdir_p!(Path.join(output_dir, "css"))

    book_infos = build_book_infos(books_with_content)
    commentary_dir = Application.get_env(:ahcip, :commentary_dir, "commentary")
    comments_by_book = load_comments(commentary_dir)

    # Render index
    index_html = render_index(book_infos)
    File.write!(Path.join(output_dir, "index.html"), index_html)

    # Render each book
    for {book, content} <- books_with_content do
      book_comments = Map.get(comments_by_book, book.number, [])
      book_html = render_book(book, content, book_infos, book_comments)
      File.write!(Path.join(output_dir, "book_#{book.number}.html"), book_html)
    end

    # Copy CSS
    copy_css(output_dir)

    :ok
  end

  defp build_book_infos(books_with_content) do
    scholar_books = MapSet.new(Enum.map(books_with_content, fn {book, _} -> book.number end))

    for n <- 1..24 do
      book = Enum.find(books_with_content, fn {b, _} -> b.number == n end)

      %{
        number: n,
        has_scholar:
          MapSet.member?(scholar_books, n) && book != nil && length(elem(book, 0).lines) > 0,
        line_count: if(book, do: length(elem(book, 0).lines), else: 0)
      }
    end
  end

  @doc """
  Render the index page.
  """
  def render_index(book_infos) do
    nav = render_nav(book_infos, 0)

    content =
      EEx.eval_file(
        Path.join(@templates_dir, "index.eex"),
        assigns: [nav: nav, books: book_infos]
      )

    render_layout("Home", content)
  end

  @doc """
  Render a single book page.
  """
  def render_book(book, content, book_infos, comments \\ []) do
    nav = render_nav(book_infos, book.number)
    display_title = AHCIP.ButlerFallback.display_title(book)

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
          comments: comments
        ]
      )

    render_layout(display_title, book_content)
  end

  defp render_nav(book_infos, current_book) do
    EEx.eval_file(
      Path.join(@templates_dir, "nav.eex"),
      assigns: [books: book_infos, current_book: current_book]
    )
  end

  defp render_layout(title, content) do
    EEx.eval_file(
      Path.join(@templates_dir, "layout.eex"),
      assigns: [title: title, content: content]
    )
  end

  @doc """
  Render a line's text with inline Greek glosses styled and annotation popovers.
  """
  def render_line_text(line, _book_number) do
    text = line.text

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

  @doc """
  Load comments from per-author commentary markdown files, grouped by Iliad book number.
  Returns %{book_number => [comment, ...]} sorted by start_line.
  Gracefully returns empty map if directory is missing.
  """
  def load_comments(commentary_dir) do
    if File.dir?(commentary_dir) do
      CommentaryParser.load(commentary_dir)
      |> Enum.filter(&(&1["work"] == "iliad"))
      |> Enum.group_by(& &1["book"])
      |> Enum.into(%{}, fn {book, comments} ->
        {book, Enum.sort_by(comments, & &1["start_line"])}
      end)
    else
      %{}
    end
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

  defp copy_css(output_dir) do
    css_src = Path.join([__DIR__, "..", "..", "assets", "css", "style.css"]) |> Path.expand()

    if File.exists?(css_src) do
      File.cp!(css_src, Path.join(output_dir, "css/style.css"))
    end
  end
end
