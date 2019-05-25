defmodule LomewakiTest do
  use ExUnit.Case
  doctest Lomewaki

  test "greets the world" do
    assert Lomewaki.hello() == :world
  end
end
