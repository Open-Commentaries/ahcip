defmodule AHCIP.Translations do
  @moduledoc """
  Maps scholar translation filenames to Iliad book numbers.
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

  @doc """
  Returns the mapping of scholar translation filenames to Iliad book numbers.
  """
  @spec iliad_file_mapping() :: %{String.t() => integer()}
  def iliad_file_mapping, do: @iliad_file_mapping
end
