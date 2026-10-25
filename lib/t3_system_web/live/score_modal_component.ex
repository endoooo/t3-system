defmodule T3SystemWeb.ScoreModalComponent do
  @moduledoc """
  The "Editar Resultados" modal: one row per set (add/remove rows), the set
  winners inferred from the scores, and the match winner.

  Saving updates the match, recalculates its table's times and sends
  `{T3SystemWeb.ScoreModalComponent, :saved}` to the parent LiveView, which
  closes the modal. Closing without saving sends the parent's `on_close`
  event.

      <.live_component
        :if={@score_match}
        module={T3SystemWeb.ScoreModalComponent}
        id="score-modal"
        match={@score_match}
        labels={{"Ana", "Bia"}}
        scope={@current_scope}
        event={@event}
        on_close="close_score_modal"
      />
  """
  use T3SystemWeb, :live_component

  alias T3System.Matches
  alias T3System.Registrations.Registration

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} title={gettext("Editar Resultados")} on_close={@on_close}>
        <% sets_by_num = Map.new(@match.sets, &{&1.set_number, &1}) %>
        <form
          id="score-form"
          phx-change="change_scores"
          phx-submit="save_scores"
          phx-target={@myself}
          class="space-y-6"
        >
          <div>
            <div class="grid w-full grid-cols-[min-content_minmax(0,1fr)_min-content_minmax(0,1fr)_2.5rem] items-center gap-2 text-center">
              <%!-- Column headers --%>
              <div class="col-span-5 grid grid-cols-subgrid items-center text-xs text-fg-muted">
                <span>{gettext("Set")}</span>
                <span class="truncate text-fg">
                  <span class="font-bold text-fg-muted">P1</span> {elem(@labels, 0)}
                </span>
                <span>vs</span>
                <span class="truncate text-fg">
                  <span class="font-bold text-fg-muted">P2</span> {elem(@labels, 1)}
                </span>
              </div>
              <%!-- Set rows --%>
              <div :for={n <- 1..@set_count} class="col-span-5 grid grid-cols-subgrid items-center">
                <% set = Map.get(sets_by_num, n)
                typed = @typed_sets[to_string(n - 1)] %>
                <input :if={set} type="hidden" name={"sets[#{n - 1}][id]"} value={set.id} />
                <input type="hidden" name={"sets[#{n - 1}][set_number]"} value={n} />
                <span class="text-xs text-fg-muted">{n}</span>
                <.input
                  id={"score-#{n}-1"}
                  type="number"
                  name={"sets[#{n - 1}][score1]"}
                  value={if typed, do: typed["score1"], else: set && set.score1}
                  label={gettext("Set %{n}, P1", n: n)}
                  sr_only
                  min="0"
                  class="text-center"
                />
                <span class="text-xs text-fg-muted">x</span>
                <.input
                  id={"score-#{n}-2"}
                  type="number"
                  name={"sets[#{n - 1}][score2]"}
                  value={if typed, do: typed["score2"], else: set && set.score2}
                  label={gettext("Set %{n}, P2", n: n)}
                  sr_only
                  min="0"
                  class="text-center"
                />
                <.icon_button
                  :if={@set_count > 1}
                  id={"remove-set-#{n}"}
                  name="hero-x-circle-mini"
                  sr_label={gettext("Remove set")}
                  tone="danger"
                  phx-click="remove_score_row"
                  phx-target={@myself}
                />
              </div>
            </div>
            <%!-- Add set button --%>
            <.button
              type="button"
              variant="ghost"
              size="sm"
              phx-click="add_score_row"
              phx-target={@myself}
              class="mt-3 -ml-3"
            >
              <.icon name="hero-plus-micro" class="size-3.5" /> {gettext("Adicionar set")}
            </.button>
          </div>
          <%!-- Match Winner --%>
          <.input
            id="winner-registration-id"
            type="select"
            name="winner_registration_id"
            label={gettext("Vencedor da partida")}
            prompt={gettext("No winner yet")}
            options={winner_options(@match, @labels)}
            value={@typed_winner || @match.winner_registration_id}
          />
          <.form_actions align="end">
            <.button type="button" phx-click={@on_close}>{gettext("Cancelar")}</.button>
            <.button type="submit" variant="primary">{gettext("Salvar")}</.button>
          </.form_actions>
        </form>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # A new match starts with its own sets (at least 3 rows, enough to show
    # every saved set number) and nothing typed yet
    socket =
      if socket.assigns[:set_count_for] == socket.assigns.match.id,
        do: socket,
        else:
          assign(socket,
            set_count: Enum.max([3 | Enum.map(socket.assigns.match.sets, & &1.set_number)]),
            set_count_for: socket.assigns.match.id,
            typed_sets: %{},
            typed_winner: nil
          )

    {:ok, socket}
  end

  @impl true
  # Keep what was typed so re-renders (adding/removing rows) don't wipe it
  def handle_event("change_scores", params, socket) do
    {:noreply,
     assign(socket,
       typed_sets: params["sets"] || %{},
       typed_winner: params["winner_registration_id"]
     )}
  end

  def handle_event("add_score_row", _params, socket) do
    {:noreply, update(socket, :set_count, &(&1 + 1))}
  end

  def handle_event("remove_score_row", _params, socket) do
    {:noreply, update(socket, :set_count, &max(&1 - 1, 1))}
  end

  def handle_event("save_scores", params, socket) do
    %{match: match, scope: scope, event: event} = socket.assigns

    sets =
      (params["sets"] || %{})
      |> Enum.reject(fn {_, s} -> s["score1"] in [nil, ""] and s["score2"] in [nil, ""] end)
      |> Map.new(fn {k, s} ->
        {k, Map.put(s, "winner_registration_id", infer_set_winner(s, match))}
      end)

    attrs = %{"sets" => sets, "winner_registration_id" => params["winner_registration_id"]}

    case Matches.update_match(scope, match, attrs) do
      {:ok, _} ->
        # Finishing (or reopening) a match changes which times are frozen on its table
        if match.table_id, do: Matches.recalculate_table_schedule(scope, event, match.table_id)

        send(self(), {__MODULE__, :saved})
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save scores."))}
    end
  end

  defp infer_set_winner(set_params, match) do
    with {s1, ""} <- Integer.parse(set_params["score1"] || ""),
         {s2, ""} <- Integer.parse(set_params["score2"] || "") do
      cond do
        s1 > s2 -> match.registration1_id
        s2 > s1 -> match.registration2_id
        true -> nil
      end
    else
      _ -> nil
    end
  end

  defp winner_options(match, {label1, label2}) do
    for {registration, registration_id, label} <- [
          {match.registration1, match.registration1_id, label1},
          {match.registration2, match.registration2_id, label2}
        ],
        is_struct(registration, Registration),
        do: {label, registration_id}
  end
end
