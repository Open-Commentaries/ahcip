defmodule Kodon.Annotation do
  @type annotation_type ::
          :greek_gloss
          | :note
          | :variant
          | :cross_ref
          | :editorial

  @type t :: %__MODULE__{
          type: annotation_type(),
          content: String.t(),
          refs: [String.t()]
        }

  defstruct [:type, :content, refs: []]
end
