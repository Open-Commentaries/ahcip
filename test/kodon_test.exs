defmodule KodonTest do
  use ExUnit.Case

  test "iliad_file_mapping returns expected book numbers" do
    mapping = Kodon.iliad_file_mapping()
    assert mapping["Iliad 01.txt"] == 1
    assert mapping["Andromache's lament in Iliad 22.txt"] == 22
    assert map_size(mapping) == 12
  end
end
