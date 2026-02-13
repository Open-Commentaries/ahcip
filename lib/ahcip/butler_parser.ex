defmodule AHCIP.ButlerParser do
  @moduledoc """
  Deprecated: Use `AHCIP.TEIParser` instead.

  This module delegates to TEIParser for backward compatibility.
  """

  defdelegate parse_file(path), to: AHCIP.TEIParser
  defdelegate lookup(data, book, start_line, end_line), to: AHCIP.TEIParser
  defdelegate book_last_line(data, book), to: AHCIP.TEIParser
end
