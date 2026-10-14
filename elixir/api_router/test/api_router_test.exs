defmodule ApiRouterTest do
  use ExUnit.Case
  doctest ApiRouter

  test "greets the world" do
    assert ApiRouter.hello() == :world
  end
end
