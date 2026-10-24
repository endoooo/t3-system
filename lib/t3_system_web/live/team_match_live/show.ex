defmodule T3SystemWeb.TeamMatchLive.Show do
  @moduledoc """
  A team match's page: its header (category, stage, teams, derived score and
  status), the matches played inside it (as match cards, in creation order)
  and each team's players. Superusers add, edit, delete and score the matches
  inside it, and set the team match winner here.
  """
  use T3SystemWeb, :live_view

  alias T3System.Accounts.Scope
  alias T3System.Events
  alias T3System.Matches
  alias T3System.Matches.Match
  alias T3System.Registrations.Registration
  alias T3System.Tables

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl space-y-8 px-4 py-8 sm:px-8">
        <.link
          navigate={@back_path}
          class="inline-flex items-center gap-1 text-sm text-fg-muted transition-colors hover:text-fg"
        >
          <.icon name="hero-arrow-left-mini" /> {gettext("Voltar")}
        </.link>

        <%!-- Header --%>
        <header id="team-match-header" class="space-y-4">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div class="min-w-0">
              <p class="text-sm text-fg-muted">{match_category(@team_match).name}</p>
              <p class="font-display text-sm font-bold text-fg-muted">
                {stage_label(@team_match)}
              </p>
            </div>
            <div class="flex items-center gap-2">
              <.badge tone={status_tone(@status)}>{status_label(@status)}</.badge>
              <.button :if={@is_superuser} phx-click="open_winner_modal">
                {gettext("Resultado")}
              </.button>
            </div>
          </div>

          <.card class="flex items-center gap-4">
            <.team_side
              registration={@team_match.registration1}
              name={team_name(@team_match, 1)}
              won={winner?(@team_match, @team_match.registration1_id)}
              class="justify-end text-right"
            />
            <div class="shrink-0 font-display text-2xl font-black text-primary tabular-nums">
              {elem(@score, 0)} — {elem(@score, 1)}
            </div>
            <.team_side
              registration={@team_match.registration2}
              name={team_name(@team_match, 2)}
              won={winner?(@team_match, @team_match.registration2_id)}
            />
          </.card>
        </header>

        <%!-- Matches inside the team match --%>
        <section id="team-match-matches" class="space-y-4">
          <.section_title>
            {gettext("Partidas")}
            <:actions :if={@is_superuser and teams(@team_match) |> length() == 2}>
              <.button phx-click="open_new_inner" variant="primary">
                <.icon name="hero-plus" /> {gettext("Adicionar partida")}
              </.button>
            </:actions>
          </.section_title>
          <.empty_state :if={@inner_cards == []} icon="hero-trophy">
            {gettext("Nenhuma partida ainda.")}
          </.empty_state>
          <div :if={@inner_cards != []} class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <.match_card
              :for={card <- @inner_cards}
              card={card}
              is_superuser={@is_superuser}
              edit_event="open_edit_inner"
            />
          </div>
        </section>

        <%!-- Each team's players --%>
        <section class="space-y-4">
          <.section_title>{gettext("Equipes")}</.section_title>
          <div class="grid gap-3 sm:grid-cols-2">
            <.card
              :for={team <- teams(@team_match)}
              id={"team-#{team.id}"}
              class="space-y-3"
            >
              <h3 class="font-display text-lg font-black">{team.name}</h3>
              <.team_members players={team.registration_players} />
            </.card>
          </div>
        </section>
      </div>

      <.modal
        :if={@winner_form}
        id="team-match-winner-modal"
        title={gettext("Resultado")}
        on_close="close_winner_modal"
      >
        <.form
          for={@winner_form}
          id="team-match-winner-form"
          phx-submit="save_winner"
          class="space-y-6"
        >
          <.input
            field={@winner_form[:winner_registration_id]}
            type="select"
            label={gettext("Vencedor")}
            prompt={gettext("Nenhum")}
            options={winner_options(@team_match)}
          />
          <.form_actions align="end">
            <.button type="button" phx-click="close_winner_modal">{gettext("Cancelar")}</.button>
            <.button type="submit" variant="primary">{gettext("Salvar")}</.button>
          </.form_actions>
        </.form>
      </.modal>

      <%!-- Add/edit a match inside the team match --%>
      <.modal
        :if={@inner_form}
        id="inner-match-modal"
        title={if @inner_editing, do: gettext("Editar partida"), else: gettext("Adicionar partida")}
        on_close="close_inner_modal"
      >
        <.form
          for={@inner_form}
          id="inner-match-form"
          phx-change="validate_inner"
          phx-submit="save_inner"
          class="space-y-6"
        >
          <div class="space-y-5">
            <.input
              field={@inner_form[:kind]}
              type="select"
              label={gettext("Tipo")}
              options={[{gettext("Simples"), "singles"}, {gettext("Duplas"), "doubles"}]}
            />
            <fieldset
              :for={{team, side} <- Enum.with_index(teams(@team_match), 1)}
              id={"inner-match-side-#{side}"}
              class="space-y-4"
            >
              <legend class="mb-2 font-display text-sm font-bold">{team.name}</legend>
              <.input
                field={@inner_form[:"position#{side}"]}
                type="text"
                label={gettext("Posição — %{team}", team: team.name)}
              />
              <.input
                :for={n <- 1..player_count(@inner_form)}
                id={"inner-match-player-#{side}-#{n}"}
                name={"inner_match[player_ids#{side}][#{n - 1}]"}
                type="select"
                label={gettext("Jogador %{n} — %{team}", n: n, team: team.name)}
                prompt={gettext("Selecione um jogador")}
                options={Enum.map(team.registration_players, &{&1.player.name, &1.player_id})}
                value={Enum.at(side_player_ids(@inner_form, side), n - 1)}
                errors={
                  if n == player_count(@inner_form), do: side_errors(@inner_form, side), else: []
                }
              />
            </fieldset>
            <.input
              id="inner-match-table"
              name="inner_match[table_id]"
              type="select"
              label={gettext("Mesa")}
              prompt={gettext("Sem mesa")}
              options={Enum.map(@tables, &{&1.name, &1.id})}
              value={@inner_table_id}
            />
          </div>
          <.form_actions align="end">
            <.button
              :if={@inner_editing}
              type="button"
              variant="danger"
              class="mr-auto"
              phx-click="delete_inner"
              data-confirm={gettext("Are you sure?")}
            >
              {gettext("Excluir")}
            </.button>
            <.button type="button" phx-click="close_inner_modal">{gettext("Cancelar")}</.button>
            <.button type="submit" variant="primary">{gettext("Salvar")}</.button>
          </.form_actions>
        </.form>
      </.modal>

      <.live_component
        :if={@score_match}
        module={T3SystemWeb.ScoreModalComponent}
        id="score-modal"
        match={@score_match}
        labels={{match_side_names(@score_match, 1, :full), match_side_names(@score_match, 2, :full)}}
        scope={@current_scope}
        event={@event}
        on_close="close_score_modal"
      />
    </Layouts.app>
    """
  end

  attr :registration, :any, required: true
  attr :name, :string, required: true
  attr :won, :boolean, required: true
  attr :class, :any, default: nil

  defp team_side(assigns) do
    ~H"""
    <div class={["flex min-w-0 flex-1 items-center gap-1.5", @class]}>
      <span class={["truncate font-display text-lg", if(@won, do: "font-bold", else: "text-fg-muted")]}>
        {@name}
      </span>
      <.icon :if={@won} name="hero-check-mini" class="shrink-0 text-primary" />
    </div>
    """
  end

  @impl true
  def mount(%{"id" => event_id, "team_match_id" => team_match_id}, _session, socket) do
    event = Events.get_event!(event_id)
    team_match = Matches.get_team_match!(event.id, team_match_id)

    if connected?(socket), do: Events.subscribe_event(event.id)

    {:ok,
     socket
     |> assign(:event, event)
     |> assign(:is_superuser, Scope.superuser?(socket.assigns.current_scope))
     |> assign(:winner_form, nil)
     |> assign(:inner_form, nil)
     |> assign(:inner_editing, nil)
     |> assign(:inner_table_id, nil)
     |> assign(:score_match, nil)
     |> assign(:tables, [])
     |> assign_team_match(team_match)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    %{event: event, team_match: team_match} = socket.assigns

    back_params = %{
      tab: params["tab"] || "matches",
      category_id: params["category_id"] || match_category(team_match).id
    }

    {:noreply, assign(socket, :back_path, ~p"/events/#{event}?#{back_params}")}
  end

  # Another process changed the event: reload the team match, or go back to
  # the event if it was deleted
  @impl true
  def handle_info({:event_updated, event_id}, socket) do
    Events.flush_event_updates(event_id)

    case Matches.get_team_match(event_id, socket.assigns.team_match.id) do
      nil -> {:noreply, push_navigate(socket, to: socket.assigns.back_path)}
      team_match -> {:noreply, assign_team_match(socket, team_match)}
    end
  end

  def handle_info({T3SystemWeb.ScoreModalComponent, :saved}, socket) do
    {:noreply, socket |> assign(:score_match, nil) |> reload_team_match()}
  end

  @impl true
  def handle_event("open_winner_modal", _params, socket) do
    form =
      to_form(%{"winner_registration_id" => socket.assigns.team_match.winner_registration_id},
        as: :team_match
      )

    {:noreply, assign(socket, :winner_form, form)}
  end

  def handle_event("close_winner_modal", _params, socket) do
    {:noreply, assign(socket, :winner_form, nil)}
  end

  def handle_event("save_winner", %{"team_match" => attrs}, socket) do
    %{current_scope: scope, team_match: team_match} = socket.assigns
    attrs = Map.take(attrs, ["winner_registration_id"])

    case Matches.update_match(scope, team_match, attrs) do
      {:ok, _} ->
        {:noreply, socket |> assign(:winner_form, nil) |> reload_team_match()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save the result."))}
    end
  end

  # Matches inside the team match (superuser only)

  def handle_event("open_new_inner", _params, socket) do
    {:noreply, open_inner_modal(socket, %Match{})}
  end

  def handle_event("open_edit_inner", %{"id" => id}, socket) do
    case find_inner(socket, id) do
      nil -> {:noreply, socket}
      match -> {:noreply, open_inner_modal(socket, match)}
    end
  end

  def handle_event("close_inner_modal", _params, socket) do
    {:noreply, assign(socket, inner_form: nil, inner_editing: nil)}
  end

  def handle_event("validate_inner", %{"inner_match" => params}, socket) do
    attrs = normalize_inner_params(params)

    {:noreply,
     socket
     |> assign(:inner_table_id, attrs["table_id"])
     |> assign(:inner_form, inner_form(socket, attrs, :validate))}
  end

  def handle_event("save_inner", %{"inner_match" => params}, socket) do
    %{current_scope: scope, team_match: team_match, inner_editing: editing} = socket.assigns
    attrs = normalize_inner_params(params)

    result =
      if editing,
        do: Matches.update_inner_match(scope, team_match, editing, attrs),
        else: Matches.create_inner_match(scope, team_match, attrs)

    case result do
      {:ok, _match} ->
        {:noreply,
         socket
         |> assign(inner_form: nil, inner_editing: nil)
         |> reload_team_match()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:inner_table_id, attrs["table_id"])
         |> assign(:inner_form, to_form(changeset, as: :inner_match))}
    end
  end

  def handle_event("delete_inner", _params, socket) do
    %{current_scope: scope, inner_editing: match} = socket.assigns

    case Matches.delete_match(scope, match) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(inner_form: nil, inner_editing: nil)
         |> reload_team_match()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Não foi possível excluir a partida."))}
    end
  end

  # Scores (superuser only)

  def handle_event("open_score_modal", %{"id" => id}, socket) do
    {:noreply, assign(socket, :score_match, find_inner(socket, id))}
  end

  def handle_event("close_score_modal", _params, socket) do
    {:noreply, assign(socket, :score_match, nil)}
  end

  defp open_inner_modal(socket, %Match{} = match) do
    socket
    |> assign(:inner_editing, if(match.id, do: match))
    |> assign(:inner_table_id, match.table_id)
    |> assign(:tables, Tables.list_tables_for_event(socket.assigns.event.id))
    |> then(&assign(&1, :inner_form, inner_form(&1, %{})))
  end

  defp inner_form(socket, attrs, action \\ nil) do
    %{team_match: team_match, inner_editing: editing} = socket.assigns

    team_match
    |> Matches.change_inner_match(editing || %Match{}, attrs)
    |> Map.put(:action, action)
    |> to_form(as: :inner_match)
  end

  # The player selects post `%{"0" => id, "1" => id}`; the context takes lists
  defp normalize_inner_params(params) do
    Enum.reduce(["player_ids1", "player_ids2"], params, fn key, acc ->
      Map.put(acc, key, picked_ids(acc[key]))
    end)
  end

  defp picked_ids(%{} = by_index) do
    by_index
    |> Enum.sort_by(fn {index, _} -> String.to_integer(index) end)
    |> Enum.map(fn {_, id} -> id end)
    |> Enum.reject(&(&1 in [nil, ""]))
  end

  defp picked_ids(_), do: []

  defp find_inner(socket, id) do
    id = String.to_integer(id)
    Enum.find(socket.assigns.team_match.inner_matches, &(&1.id == id))
  end

  defp player_count(form), do: Match.side_player_count(form[:kind].value)

  defp side_player_ids(form, side), do: form[:"player_ids#{side}"].value || []

  defp side_errors(form, side) do
    if form.source.action,
      do: Enum.map(form[:"player_ids#{side}"].errors, &translate_error/1),
      else: []
  end

  defp reload_team_match(socket) do
    %{event: event, team_match: team_match} = socket.assigns
    assign_team_match(socket, Matches.get_team_match!(event.id, team_match.id))
  end

  defp assign_team_match(socket, %Match{} = team_match) do
    inner_matches = team_match.inner_matches

    socket
    |> assign(:team_match, team_match)
    |> assign(:inner_cards, inner_cards(inner_matches))
    |> assign(:score, Matches.team_match_score(team_match, inner_matches))
    |> assign(:status, Matches.team_match_status(team_match, inner_matches))
    |> assign(:page_title, "#{team_name(team_match, 1)} x #{team_name(team_match, 2)}")
  end

  defp inner_cards(inner_matches) do
    inner_matches
    |> Enum.with_index(1)
    |> Enum.map(fn {match, n} ->
      inner_match_card_data(match, label: gettext("Partida %{n}", n: n))
    end)
  end

  defp teams(%Match{} = team_match),
    do:
      Enum.filter(
        [team_match.registration1, team_match.registration2],
        &is_struct(&1, Registration)
      )

  defp winner?(%Match{winner_registration_id: nil}, _registration_id), do: false

  defp winner?(%Match{winner_registration_id: winner_id}, registration_id),
    do: winner_id == registration_id

  defp winner_options(%Match{} = team_match),
    do: Enum.map(teams(team_match), &{&1.name, &1.id})

  defp status_label(:finished), do: gettext("Finalizado")
  defp status_label(:ongoing), do: gettext("Em andamento")
  defp status_label(:pending), do: gettext("Pendente")

  defp status_tone(:finished), do: "primary"
  defp status_tone(:ongoing), do: "success"
  defp status_tone(:pending), do: "neutral"
end
