defmodule T3SystemWeb.PlayerComponents do
  @moduledoc """
  Displays a list of players, e.g. a registration's single player or a pair.

  Each entry is a map with a `:player` (`name`, `picture_url`) and a `:club`
  (`name`), in display order. Taking players instead of a registration lets
  pairs that aren't registrations reuse it (see
  `docs/adr/0001-registration-players-as-a-list.md`).
  """
  use Phoenix.Component

  import T3SystemWeb.CoreComponents, only: [avatar: 1]

  @separator " / "

  @doc """
  Renders players' overlapping avatars, their names joined by " / " and,
  optionally, their clubs.

  The inner block is rendered right after the names (e.g. a status icon).

  ## Examples

      <.players players={players} avatar_size="xs" />
      <.players players={players} avatar_size="md" show_clubs names_tag="h3" />
  """
  attr :players, :list, required: true, doc: "entries with `:player` and `:club`"
  attr :avatar_size, :string, default: nil, doc: "avatar size, or nil to hide avatars"
  attr :preview, :boolean, default: true, doc: "open a larger picture on avatar click"
  attr :show_clubs, :boolean, default: false
  attr :names_tag, :string, default: "span"
  attr :class, :any, default: "gap-2", doc: "classes for the outer flex container"
  attr :body_class, :any, default: nil, doc: "classes for the names/clubs column"
  attr :names_class, :any, default: nil
  attr :clubs_class, :any, default: "text-sm text-primary"
  slot :inner_block

  def players(assigns) do
    assigns = assign(assigns, :pair?, length(assigns.players) > 1)

    ~H"""
    <div class={["flex min-w-0 items-center", @class]}>
      <div :if={@avatar_size} class={["flex shrink-0", @pair? && "-space-x-2"]}>
        <.avatar
          :for={entry <- @players}
          src={entry.player.picture_url}
          name={entry.player.name}
          size={@avatar_size}
          preview={@preview}
          class={@pair? && "ring-2 ring-surface"}
        />
      </div>
      <div class={["min-w-0 flex-1", @body_class]}>
        <.dynamic_tag tag_name={@names_tag} class={@names_class}>
          {player_names(@players)}
        </.dynamic_tag>
        {render_slot(@inner_block)}
        <p :if={@show_clubs} class={@clubs_class}>{player_clubs(@players)}</p>
      </div>
    </div>
    """
  end

  @doc ~s(Players' names joined by " / ", e.g. "Ana / Bia".)
  def player_names(players), do: Enum.map_join(players, @separator, & &1.player.name)

  @doc "Players' clubs joined by \" / \"."
  def player_clubs(players), do: Enum.map_join(players, @separator, & &1.club.name)

  @doc "Each player's name with their club, e.g. \"Ana — A / Bia — B\"."
  def player_names_with_clubs(players) do
    Enum.map_join(players, @separator, &"#{&1.player.name} — #{&1.club.name}")
  end
end
