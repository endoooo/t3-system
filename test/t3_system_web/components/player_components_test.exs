defmodule T3SystemWeb.PlayerComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias T3SystemWeb.PlayerComponents

  defp entry(name, club, picture_url \\ nil) do
    %{player: %{name: name, picture_url: picture_url}, club: %{name: club}}
  end

  describe "players/1" do
    test "renders a single player's name and avatar" do
      html =
        render_component(&PlayerComponents.players/1,
          players: [entry("Ana", "Clube A", "https://example.com/ana.jpg")],
          avatar_size: "md"
        )

      assert html =~ "Ana"
      assert html =~ ~s(alt="Ana")
      refute html =~ "Clube A"
    end

    test "joins a pair's names with a slash and shows both avatars" do
      html =
        render_component(&PlayerComponents.players/1,
          players: [
            entry("Ana", "Clube A", "https://example.com/ana.jpg"),
            entry("Bia", "Clube B", "https://example.com/bia.jpg")
          ],
          avatar_size: "xs"
        )

      assert html =~ "Ana / Bia"
      assert html =~ ~s(alt="Ana")
      assert html =~ ~s(alt="Bia")
    end

    test "shows the clubs when asked" do
      html =
        render_component(&PlayerComponents.players/1,
          players: [entry("Ana", "Clube A"), entry("Bia", "Clube B")],
          show_clubs: true
        )

      assert html =~ "Clube A / Clube B"
    end

    test "with lines, puts each player of a pair on its own line" do
      html =
        render_component(&PlayerComponents.players/1,
          players: [entry("Ana", "Clube A"), entry("Bia", "Clube B")],
          lines: true
        )

      lines = html |> LazyHTML.from_fragment() |> LazyHTML.query("li")
      assert Enum.map(lines, &String.trim(LazyHTML.text(&1))) == ["Ana", "Bia"]
      refute html =~ "Ana / Bia"
    end

    test "renders the inner block after the names" do
      assigns = %{players: [entry("Ana", "Clube A")]}

      html =
        rendered_to_string(~H"""
        <PlayerComponents.players players={@players}>
          <em>extra</em>
        </PlayerComponents.players>
        """)

      assert html =~ "<em>extra</em>"
    end
  end

  describe "player_names/1" do
    test "joins names with a slash" do
      assert PlayerComponents.player_names([entry("Ana", "A"), entry("Bia", "B")]) ==
               "Ana / Bia"

      assert PlayerComponents.player_names([entry("Ana", "A")]) == "Ana"
    end
  end

  describe "player_clubs/1" do
    test "names a shared club once" do
      assert PlayerComponents.player_clubs([entry("Ana", "A"), entry("Bia", "B")]) == "A / B"
      assert PlayerComponents.player_clubs([entry("Ana", "A"), entry("Bia", "A")]) == "A"
    end
  end

  describe "player_names_with_clubs/1" do
    test "pairs each name with its club" do
      assert PlayerComponents.player_names_with_clubs([entry("Ana", "A")]) == "Ana — A"

      assert PlayerComponents.player_names_with_clubs([entry("Ana", "A"), entry("Bia", "B")]) ==
               "Ana — A / Bia — B"
    end
  end
end
