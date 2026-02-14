defmodule Kodon.Line do
  @type t :: %__MODULE__{
          number: String.t(),
          sort_key: {integer(), String.t()},
          text: String.t(),
          raw_text: String.t(),
          annotations: [Kodon.Annotation.t()]
        }

  defstruct [:number, :sort_key, :text, :raw_text, annotations: []]

  @doc """
  Parse a line number string like "1", "40a", "302 v.l." into a sort key.
  Returns {integer, suffix} for ordering.
  """
  def sort_key(number_str) do
    number_str = String.trim(number_str)

    case Regex.run(~r/^(\d+)(.*)$/, number_str) do
      [_, digits, suffix] -> {String.to_integer(digits), String.trim(suffix)}
      _ -> {0, number_str}
    end
  end
end
