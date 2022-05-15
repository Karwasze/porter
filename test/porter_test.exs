defmodule PorterTest do
  use ExUnit.Case
  doctest Porter

  test "greets the world" do
    assert Porter.hello() == :world
  end
end
