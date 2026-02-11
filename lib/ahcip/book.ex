defmodule AHCIP.Book do
  @type t :: %__MODULE__{
          number: integer(),
          title: String.t(),
          preamble: String.t() | nil,
          translators: [String.t()],
          lines: [AHCIP.Line.t()],
          source_file: String.t() | nil
        }

  defstruct [:number, :title, :preamble, :source_file, translators: [], lines: []]
end
