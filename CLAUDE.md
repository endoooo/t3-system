# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Setup
mix setup

# Run server
mix phx.server

# Run all tests
mix test

# Run a single test file
mix test test/t3_system/players_test.exs

# Run a single test by line
mix test test/t3_system/players_test.exs:42

# Lint, format, and full test suite (run before committing)
mix precommit

# Create a new migration
mix ecto.gen.migration migration_description
# then edit the generated file in priv/repo/migrations/

# Reset database
mix ecto.reset
```

## Architecture

Standard Phoenix 1.8 app with LiveView. Two main OTP apps: `T3System` (business logic) and `T3SystemWeb` (web layer).

**Contexts** live in `lib/t3_system/` — currently `Accounts` (users, auth) and `Players`.

**LiveViews** live in `lib/t3_system_web/live/` — grouped by resource (e.g. `player_live/index.ex`, `player_live/form.ex`, `player_live/show.ex`).

### Authorization via Scope

`T3System.Accounts.Scope` wraps the current user and is threaded through the system:
- Set in the browser pipeline via `fetch_current_scope_for_user` plug
- Mounted in LiveView sessions via `on_mount: [{T3SystemWeb.UserAuth, :require_authenticated}]`
- Available in LiveView as `socket.assigns.current_scope`

Context write functions (`create_*`, `update_*`, `delete_*`) take `scope` as the first argument and pattern-match on `%Scope{user: %{role: "superuser"}}` to enforce superuser-only access. No catch-all clause is needed.

### User roles

`User.role` is a string field: `"user"` (default) or `"superuser"`. Login requires email confirmation.

## Database

Text fields in the DB use Postgres `type :text` (not `:string`/varchar). This is a DB-level choice only — in forms, these fields still use `type="text"` (not `type="textarea"`) unless multiline input is explicitly needed.

## Patterns

### Schema typespecs

Every schema must define a `@type t` typespec. Use `| nil` for nullable fields. For association fields (has_many, has_one, belongs_to, many_to_many), type as `SomeSchema.t() | Ecto.Association.NotLoaded.t()`.

```elixir
@type t :: %__MODULE__{
        id: pos_integer(),
        name: String.t(),
        picture_url: String.t() | nil,
        players: [Player.t()] | Ecto.Association.NotLoaded.t(),
        inserted_at: DateTime.t(),
        updated_at: DateTime.t()
      }
```

### Context write functions

```elixir
def create_player(%Scope{user: %{role: "superuser"}}, attrs) do
  %Player{} |> Player.changeset(attrs) |> Repo.insert()
end
```

### Tests

Use ExMachina factories (`test/support/factory.ex`), not fixtures. For LiveView tests, use the PhoenixTest pattern:

```elixir
import PhoenixTest
import T3System.Factory

conn
|> visit(~p"/player")
|> assert_has("h1", text: "Listing Player")
|> fill_in("Name", with: "some name")
|> click_button("Save Player")
```

Factories: `insert(:player)`, `insert(:user)`, `insert(:superuser)`.

Use `start_supervised!/1` to start processes in tests — it guarantees cleanup between tests. Avoid `Process.sleep/1`.

## Phoenix 1.8 conventions

### LiveView templates

Always begin LiveView `render/1` with `<Layouts.app flash={@flash}>` wrapping all content. `T3SystemWeb.Layouts` is already aliased in `t3_system_web.ex` — no need to alias it again.

`<.flash_group>` is **forbidden** outside `layouts.ex` — it is managed by the `Layouts` module.

### Icons and inputs

- Use `<.icon name="hero-x-mark" />` for icons. Never use `Heroicons` modules directly.
- Use the `<.input>` component from `core_components.ex` for all form inputs.

### Authentication in templates

Access the current user as `@current_scope.user`. There is no `@current_user` assign.

### Router placement

The router has named `live_session` blocks that must not be duplicated. Place new routes in the existing block matching the required auth level:
- Authenticated routes → existing `:players` or `:require_authenticated_user` `live_session` block
- Optional auth routes → existing `:current_user` `live_session` block

Router `scope` blocks have an alias prefix — avoid duplicating it in `live` route module names.

### HTTP client

Use `Req` (already a dependency) for all HTTP requests. Never use `:httpoison`, `:tesla`, or `:httpc`.

### Internationalization (i18n)

All user-facing text in templates must use `gettext` for i18n support:

```heex
<h1><%= gettext("Listing Players") %></h1>
<p><%= gettext("No players found.") %></p>
```

### Tailwind CSS

Tailwind v4 does not use `tailwind.config.js`. The `app.css` import syntax is:

```css
@import "tailwindcss" source(none);
@source "../css";
@source "../js";
@source "../../lib/t3_system_web";
```

Never use `@apply` in raw CSS.

### LiveView streams

Use streams for all collections — never assign plain lists to avoid memory issues:

```elixir
# mount
|> stream(:items, list_items())

# insert/update
|> stream_insert(:items, item)

# delete
|> stream_delete(:items, item)

# reset (e.g. after filter)
|> stream(:items, filtered_items, reset: true)
```

Streams are not enumerable — never call `Enum.filter/2` on `@streams.items`. To filter, refetch and reset.

### Forms

Always build forms with `to_form/2` and pass via an assign. Access only via `@form[:field]` in templates — never pass a changeset directly to the template.

```elixir
# LiveView
assign(socket, :form, to_form(MySchema.changeset(struct, attrs)))

# Template
<.form for={@form} id="my-form" phx-change="validate" phx-submit="save">
  <.input field={@form[:name]} type="text" label="Name" />
</.form>
```

### Inline JavaScript (colocated hooks)

Never write raw `<script>` tags in HEEx. Use colocated hooks instead:

```heex
<input id="my-input" phx-hook=".MyHook" />
<script :type={Phoenix.LiveView.ColocatedHook} name=".MyHook">
  export default {
    mounted() { ... }
  }
</script>
```

Colocated hook names **must** start with `.`. They are automatically bundled into `app.js`.
