defmodule Kodon.ButlerParser do
  @moduledoc """
  Deprecated: Use `Kodon.TEIParser` instead.

  This module delegates to TEIParser for backward compatibility.
  """

  defdelegate parse_file(path), to: Kodon.TEIParser
  defdelegate lookup(data, book, start_line, end_line), to: Kodon.TEIParser
  defdelegate book_last_line(data, book), to: Kodon.TEIParser
end
