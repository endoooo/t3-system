defmodule T3SystemWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias T3SystemWeb.CoreComponents

  describe "tooltip/1" do
    test "wraps the content and carries the full text for the tooltip hook" do
      html =
        render_component(&CoreComponents.tooltip/1,
          id: "name",
          text: "Ana Maria da Silva / Beatriz Souza",
          class: "truncate",
          inner_block: [%{inner_block: fn _, _ -> "Ana Maria da Silva / Beatriz Souza" end}]
        )

      element = html |> LazyHTML.from_fragment() |> LazyHTML.query("#name")
      assert LazyHTML.attribute(element, "data-tooltip") == ["Ana Maria da Silva / Beatriz Souza"]
      assert LazyHTML.attribute(element, "class") == ["truncate"]
      assert LazyHTML.text(element) =~ "Ana Maria da Silva / Beatriz Souza"
    end
  end
end
