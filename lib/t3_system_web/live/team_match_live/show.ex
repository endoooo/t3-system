defmodule T3SystemWeb.TeamMatchLive.Show do
  @moduledoc """
  A team match's page: its header (category, stage, teams, derived score and
  status), the matches played inside it and each team's players. Superusers
  set the team match winner here.
  """
  use T3SystemWeb, :live_view

  alias T3System.Events
  alias T3System.Matches
  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Matches.Stage
  alias T3System.Registrations.Registration

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
              <p class="text-sm text-fg-muted">{category(@team_match).name}</p>
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
          <.section_title>{gettext("Partidas")}</.section_title>
          <.empty_state icon="hero-trophy">{gettext("Nenhuma partida ainda.")}</.empty_state>
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
     |> assign(:is_superuser, superuser?(socket.assigns))
     |> assign(:winner_form, nil)
     |> assign_team_match(team_match)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    %{event: event, team_match: team_match} = socket.assigns

    back_params = %{
      tab: params["tab"] || "matches",
      category_id: params["category_id"] || category(team_match).id
    }

    {:noreply, assign(socket, :back_path, ~p"/events/#{event}?#{back_params}")}
  end

  # Another process changed the event: reload the team match, or go back to
  # the event if it was deleted
  @impl true
  def handle_info({:event_updated, event_id}, socket) do
    flush_event_updates(event_id)

    try do
      Matches.get_team_match!(event_id, socket.assigns.team_match.id)
    rescue
      Ecto.NoResultsError -> nil
    end
    |> case do
      nil -> {:noreply, push_navigate(socket, to: socket.assigns.back_path)}
      team_match -> {:noreply, assign_team_match(socket, team_match)}
    end
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
    %{current_scope: scope, team_match: team_match, event: event} = socket.assigns
    attrs = Map.take(attrs, ["winner_registration_id"])

    case Matches.update_match(scope, team_match, attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:winner_form, nil)
         |> assign_team_match(Matches.get_team_match!(event.id, team_match.id))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save the result."))}
    end
  end

  defp assign_team_match(socket, %Match{} = team_match) do
    # Matches inside team matches come with ticket 06
    inner_matches = []

    socket
    |> assign(:team_match, team_match)
    |> assign(:score, Matches.team_match_score(team_match, inner_matches))
    |> assign(:status, Matches.team_match_status(team_match, inner_matches))
    |> assign(:page_title, "#{team_name(team_match, 1)} x #{team_name(team_match, 2)}")
  end

  defp flush_event_updates(event_id) do
    receive do
      {:event_updated, ^event_id} -> flush_event_updates(event_id)
    after
      0 -> :ok
    end
  end

  defp category(%Match{group: %Group{stage: %Stage{category: category}}}), do: category
  defp category(%Match{stage: %Stage{category: category}}), do: category

  defp teams(%Match{} = team_match),
    do:
      Enum.filter(
        [team_match.registration1, team_match.registration2],
        &is_struct(&1, Registration)
      )

  defp team_name(%Match{} = team_match, n) do
    case if(n == 1, do: team_match.registration1, else: team_match.registration2) do
      %Registration{name: name} -> name
      _ -> gettext("TBD")
    end
  end

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

  defp superuser?(%{current_scope: %{user: %{role: "superuser"}}}), do: true
  defp superuser?(_assigns), do: false
end
