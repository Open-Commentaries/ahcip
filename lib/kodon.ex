defmodule Kodon do
  @moduledoc """
  A Homeric Commentary in Progress — Static Site Generator.

  Generates a static HTML reading environment for Homer's Iliad, Odyssey,
  and the Homeric Hymns, combining scholar translations with prose translations
  as fallback for untranslated sections.
  """

  @iliad_file_mapping %{
    "Iliad 01.txt" => 1,
    "Iliad 02.txt" => 2,
    "Iliad 03.txt" => 3,
    "Iliad 04.txt" => 4,
    "Iliad 05.txt" => 5,
    "Iliad 07.txt" => 7,
    "Iliad 11.txt" => 11,
    "Iliad 14.txt" => 14,
    "Iliad 15.txt" => 15,
    "Iliad 16.txt" => 16,
    "Andromache's lament in Iliad 22.txt" => 22,
    "Iliad 23.txt" => 23
  }

  def iliad_file_mapping, do: @iliad_file_mapping

  @deprecated "Use iliad_file_mapping/0 instead"
  def file_mapping, do: @iliad_file_mapping
end
