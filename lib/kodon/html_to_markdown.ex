defmodule Kodon.HtmlToMarkdown do
  @moduledoc """
  Converts a subset of HTML (as found in Kodon comment content) to Markdown.

  Handles: <p>, <em>, <i>, <strong>, <a>, <img>, <br>, <ol>/<li>, <span>.
  Passes through: <u>, <sub>, <sup> (no standard Markdown equivalent).
  """

  @doc """
  Convert an HTML string to Markdown.
  """
  def convert(nil), do: ""
  def convert(""), do: ""

  def convert(html) do
    html
    |> parse_nodes()
    |> render_nodes()
    |> String.trim()
  end

  # --- Parsing ---

  defp parse_nodes(html) do
    parse_nodes(html, [])
  end

  defp parse_nodes("", acc), do: Enum.reverse(acc)

  defp parse_nodes(html, acc) do
    case html do
      # Self-closing tags: <br>, <br/>, <br />, <img ... />
      <<"<br">> <> rest ->
        {_, rest} = consume_tag_close(rest)
        parse_nodes(rest, [{:br, %{}, []} | acc])

      <<"<img">> <> rest ->
        {attrs, rest} = consume_tag_close(rest)
        parse_nodes(rest, [{:img, parse_attrs(attrs), []} | acc])

      # Closing tag
      <<"</">> <> rest ->
        # Return remaining text after closing tag — caller handles this
        {_tag, rest} = consume_tag_name(rest)
        {_, rest} = consume_tag_close(rest)
        {Enum.reverse(acc), rest}

      # Opening tag
      <<"<">> <> rest ->
        {tag, rest} = consume_tag_name(rest)
        {attrs, rest} = consume_tag_close(rest)

        tag_atom = tag_to_atom(tag)

        if self_closing_tag?(tag_atom) do
          parse_nodes(rest, [{tag_atom, parse_attrs(attrs), []} | acc])
        else
          {children, rest} = parse_nodes(rest, [])
          parse_nodes(rest, [{tag_atom, parse_attrs(attrs), children} | acc])
        end

      # Text node
      _ ->
        {text, rest} = consume_text(html)
        parse_nodes(rest, [{:text, text} | acc])
    end
  end

  defp consume_tag_name(html) do
    case Regex.run(~r/\A([a-zA-Z0-9]+)(.*)$/s, html) do
      [_, tag, rest] -> {String.downcase(tag), rest}
      nil -> {"", html}
    end
  end

  defp consume_tag_close(html) do
    case Regex.run(~r/\A([^>]*)>(.*)$/s, html) do
      [_, attrs, rest] -> {String.trim(attrs), rest}
      nil -> {"", html}
    end
  end

  defp consume_text(html) do
    case String.split(html, "<", parts: 2) do
      [text] -> {text, ""}
      [text, rest] -> {text, "<" <> rest}
    end
  end

  defp parse_attrs(attrs_str) do
    Regex.scan(~r/(\w+)="([^"]*)"/, attrs_str)
    |> Map.new(fn [_, k, v] -> {k, v} end)
  end

  defp tag_to_atom(tag) do
    case tag do
      "p" -> :p
      "em" -> :em
      "i" -> :i
      "strong" -> :strong
      "a" -> :a
      "img" -> :img
      "br" -> :br
      "ol" -> :ol
      "li" -> :li
      "u" -> :u
      "sub" -> :sub
      "sup" -> :sup
      "span" -> :span
      "blockquote" -> :blockquote
      "h1" -> :h1
      "h2" -> :h2
      "h3" -> :h3
      "h4" -> :h4
      other -> String.to_atom(other)
    end
  end

  defp self_closing_tag?(:br), do: true
  defp self_closing_tag?(:img), do: true
  defp self_closing_tag?(_), do: false

  # --- Rendering ---

  defp render_nodes(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&render_node/1)
    |> Enum.join()
  end

  defp render_node({:text, text}) do
    decode_entities(text)
  end

  defp render_node({:p, _attrs, children}) do
    inner = render_nodes(children) |> String.trim()
    if inner == "", do: "", else: inner <> "\n\n"
  end

  defp render_node({:em, _attrs, children}) do
    inner = render_nodes(children)
    if inner == "", do: "", else: "*#{inner}*"
  end

  defp render_node({:i, _attrs, children}) do
    inner = render_nodes(children)
    if inner == "", do: "", else: "*#{inner}*"
  end

  defp render_node({:strong, _attrs, children}) do
    inner = render_nodes(children)
    if inner == "", do: "", else: "**#{inner}**"
  end

  defp render_node({:a, attrs, children}) do
    href = Map.get(attrs, "href", "")
    inner = render_nodes(children)
    if inner == "", do: "", else: "[#{inner}](#{href})"
  end

  defp render_node({:img, attrs, _children}) do
    src = Map.get(attrs, "src", "")
    alt = Map.get(attrs, "alt", "")
    "![#{alt}](#{src})"
  end

  defp render_node({:br, _attrs, _children}) do
    "  \n"
  end

  defp render_node({:ol, _attrs, children}) do
    children
    |> Enum.filter(fn
      {:li, _, _} -> true
      _ -> false
    end)
    |> Enum.with_index(1)
    |> Enum.map(fn {{:li, _attrs, li_children}, idx} ->
      inner = render_nodes(li_children) |> String.trim()
      "#{idx}. #{inner}\n"
    end)
    |> Enum.join()
    |> Kernel.<>("\n")
  end

  defp render_node({:blockquote, _attrs, children}) do
    inner = render_nodes(children) |> String.trim()

    inner
    |> String.split("\n")
    |> Enum.map(&("> " <> &1))
    |> Enum.join("\n")
    |> Kernel.<>("\n\n")
  end

  defp render_node({heading, _attrs, children}) when heading in [:h1, :h2, :h3, :h4] do
    level = heading |> Atom.to_string() |> String.last() |> String.to_integer()
    prefix = String.duplicate("#", level)
    inner = render_nodes(children) |> String.trim()
    "#{prefix} #{inner}\n\n"
  end

  # Pass-through tags: u, sub, sup, span
  defp render_node({tag, _attrs, children}) when tag in [:u, :sub, :sup] do
    inner = render_nodes(children)
    tag_str = Atom.to_string(tag)
    "<#{tag_str}>#{inner}</#{tag_str}>"
  end

  defp render_node({:span, _attrs, children}) do
    # Spans are just wrappers; render children directly
    render_nodes(children)
  end

  # Fallback: render children only
  defp render_node({_tag, _attrs, children}) do
    render_nodes(children)
  end

  defp decode_entities(text) do
    text
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&nbsp;", " ")
  end
end
