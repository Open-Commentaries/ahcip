defmodule AHCIP.Renderer do
  @moduledoc """
  Renders parsed book data into static HTML files using EEx templates.
  """

  alias AHCIP.{CrossRef, Annotation}

  @templates_dir Path.join([__DIR__, "..", "..", "templates"]) |> Path.expand()

  @doc """
  Render the entire site: index page + all book pages.
  """
  def render_site(books_with_content, output_dir) do
    File.mkdir_p!(output_dir)
    File.mkdir_p!(Path.join(output_dir, "css"))

    book_infos = build_book_infos(books_with_content)

    # Render index
    index_html = render_index(book_infos)
    File.write!(Path.join(output_dir, "index.html"), index_html)

    # Render each book
    for {book, content} <- books_with_content do
      book_html = render_book(book, content, book_infos)
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
        has_scholar: MapSet.member?(scholar_books, n) && book != nil && length(elem(book, 0).lines) > 0,
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
  def render_book(book, content, book_infos) do
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
          book_number: book.number
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
  Render a line's text with inline Greek glosses styled.
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
        String.replace(acc, gloss, ~s(<span class="greek-gloss">#{escape_html(gloss)}</span>), global: false)
      end)

    # Add cross-ref links
    cross_refs =
      line.annotations
      |> Enum.filter(&(&1.type == :cross_ref))

    ref_links =
      cross_refs
      |> Enum.flat_map(& &1.refs)
      |> Enum.map(&CrossRef.render_link/1)

    if length(ref_links) > 0 do
      text <> ~s( <span class="cross-refs">[) <> Enum.join(ref_links, ", ") <> "]</span>"
    else
      text
    end
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

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp copy_css(output_dir) do
    css_src = Path.join([__DIR__, "..", "..", "assets", "css", "style.css"]) |> Path.expand()

    if File.exists?(css_src) do
      File.cp!(css_src, Path.join(output_dir, "css/style.css"))
    end
  end
end
