defmodule LomekwiTest do
  use ExUnit.Case
  doctest Lomekwi

  test "greets the world" do
    assert Lomekwi.hello() == :world
  end
end
