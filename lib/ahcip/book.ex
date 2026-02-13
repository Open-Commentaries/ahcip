defmodule AHCIP.Book do
  @type t :: %__MODULE__{
          number: integer(),
          title: String.t(),
          preamble: String.t() | nil,
          translators: [String.t()],
          lines: [AHCIP.Line.t()],
          source_file: String.t() | nil,
          work_slug: String.t() | nil
        }

  defstruct [:number, :title, :preamble, :source_file, :work_slug, translators: [], lines: []]
end
