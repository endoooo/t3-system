defmodule T3SystemWeb.CoreComponents do
  @moduledoc """
  Provides the core UI components — the building blocks of the T3 design system.

  ## Design tokens

  Colors, radii and fonts are defined as Tailwind theme variables in
  `assets/css/app.css`. The default Tailwind palette is disabled, so only
  semantic color utilities exist:

    * Backgrounds: `canvas`, `chrome`, `surface`, `surface-raised`, `overlay`, `scrim`
    * Foreground: `fg`, `fg-muted`, `fg-subtle`
    * Lines: `border`, `border-strong`
    * Brand: `primary`, `primary-hover`, `primary-strong`, `on-primary`
    * Status: `danger`, `success`, `warning` (+ `-hover` / `-strong` variants)
    * Placements: `gold`, `silver`, `bronze`
    * Radii: `rounded-control`, `rounded-card`

  Prefer the components below over re-styling raw elements. When a component
  doesn't fit, compose with the token utilities rather than adding custom CSS.

  Useful references:

    * [Tailwind CSS theme variables](https://tailwindcss.com/docs/theme)
    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.
    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html)
  """
  use Phoenix.Component
  use Gettext, backend: T3SystemWeb.Gettext

  alias Phoenix.HTML.Form, as: HTMLForm
  alias Phoenix.LiveView.JS

  @focus_ring "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"

  @field_class [
    "block w-full appearance-none rounded-control bg-surface px-3.5 py-2.5 text-base text-fg sm:text-sm",
    "inset-ring inset-ring-border placeholder:text-fg-subtle",
    "focus:outline-2 focus:-outline-offset-1 focus:outline-primary",
    "disabled:cursor-not-allowed disabled:opacity-50"
  ]

  # `:read-only` also matches every <select>, so only apply it to text-like fields
  @text_field_class "read-only:text-fg-muted"

  @field_error_class "inset-ring-danger/60 focus:outline-danger"

  ## Feedback

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      role="alert"
      aria-live="assertive"
      class="pointer-events-none fixed inset-0 z-50 flex items-end px-4 py-6 sm:items-start sm:p-6"
      {@rest}
    >
      <div class="flex w-full flex-col items-center space-y-4 sm:items-end">
        <div class="pointer-events-auto w-full max-w-sm rounded-card bg-overlay p-4 shadow-lg inset-ring inset-ring-border">
          <div class="flex items-start gap-3">
            <.icon
              :if={@kind == :info}
              name="hero-check-circle"
              class="size-6 shrink-0 text-success"
            />
            <.icon
              :if={@kind == :error}
              name="hero-exclamation-circle"
              class="size-6 shrink-0 text-danger"
            />
            <div class="w-0 flex-1 pt-0.5">
              <p :if={@title} class="text-sm font-medium text-fg">{@title}</p>
              <p class="text-sm text-fg-muted">{msg}</p>
            </div>
            <.icon_button
              name="hero-x-mark-mini"
              sr_label={gettext("close")}
              class="-m-2"
              phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders an inline callout.

  ## Examples

      <.alert tone="warning">3 jogos pendentes sem mesa</.alert>
  """
  attr :tone, :string, default: "info", values: ~w(info success warning danger)
  attr :icon, :string, default: nil, doc: "overrides the tone's default icon"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def alert(assigns) do
    tones = %{
      "info" =>
        {"bg-primary/10 text-primary inset-ring-primary/20", "hero-information-circle-mini"},
      "success" => {"bg-success/10 text-success inset-ring-success/20", "hero-check-circle-mini"},
      "warning" =>
        {"bg-warning/10 text-warning inset-ring-warning/20", "hero-exclamation-triangle-mini"},
      "danger" => {"bg-danger/10 text-danger inset-ring-danger/20", "hero-x-circle-mini"}
    }

    {tone_class, default_icon} = Map.fetch!(tones, assigns.tone)
    assigns = assign(assigns, tone_class: tone_class, icon: assigns.icon || default_icon)

    ~H"""
    <div
      class={[
        "flex items-start gap-2.5 rounded-card px-4 py-3 text-sm inset-ring",
        @tone_class,
        @class
      ]}
      {@rest}
    >
      <.icon name={@icon} class="mt-px size-5 shrink-0" />
      <div class="min-w-0 flex-1">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  @doc """
  Renders a placeholder for empty collections.

  ## Examples

      <.empty_state>No matches yet.</.empty_state>
      <.empty_state icon="hero-trophy">No brackets yet.</.empty_state>
  """
  attr :icon, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def empty_state(assigns) do
    ~H"""
    <div class={[
      "flex flex-col items-center gap-2 rounded-card border border-dashed border-border-strong px-4 py-10 text-center text-sm text-fg-muted",
      @class
    ]}>
      <.icon :if={@icon} name={@icon} class="size-6 text-fg-subtle" />
      <p>{render_slot(@inner_block)}</p>
    </div>
    """
  end

  ## Actions

  @doc """
  Renders a button with navigation support.

  ## Variants

    * `primary` – the main call to action of a view (solid)
    * `secondary` – the default; neutral outlined action
    * `ghost` – low-emphasis text action (e.g. inline "Edit")
    * `danger` – low-emphasis destructive text action

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
      <.button variant="ghost" size="sm">Edit</.button>
  """
  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled type form)

  attr :class, :any, default: nil
  attr :variant, :string, default: "secondary", values: ~w(primary secondary ghost danger)
  attr :size, :string, default: "md", values: ~w(sm md)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" => "bg-primary text-on-primary shadow-sm hover:bg-primary-hover",
      "secondary" => "text-fg inset-ring inset-ring-border-strong hover:bg-fg/10",
      "ghost" => "text-primary hover:bg-primary/10 hover:text-primary-hover",
      "danger" => "text-danger hover:bg-danger/10 hover:text-danger-hover"
    }

    sizes = %{
      "sm" => "gap-1 px-3 py-1.5 text-xs",
      "md" => "gap-1.5 px-4 py-2.5 text-sm"
    }

    assigns =
      assign(assigns, :computed_class, [
        "inline-flex items-center justify-center rounded-full font-medium whitespace-nowrap transition-colors",
        "disabled:pointer-events-none disabled:opacity-50 phx-submit-loading:opacity-75",
        @focus_ring,
        Map.fetch!(variants, assigns.variant),
        Map.fetch!(sizes, assigns.size),
        assigns.class
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders a button that contains only an icon, sized for touch targets.

  The icon uses the mini variant (20×20) with 10px padding, resulting in a 40×40 touch area.

  ## Examples

      <.icon_button name="hero-pencil-mini" sr_label="Edit" />
      <.icon_button name="hero-trash-mini" sr_label="Delete" tone="danger" />
  """
  attr :name, :string, required: true
  attr :sr_label, :string, required: true
  attr :tone, :string, default: "neutral", values: ~w(neutral primary danger)
  attr :type, :string, default: "button"
  attr :class, :any, default: nil
  attr :rest, :global

  def icon_button(assigns) do
    tones = %{
      "neutral" => "text-fg-muted hover:bg-fg/5 hover:text-fg",
      "primary" => "text-primary hover:bg-primary/10 hover:text-primary-hover",
      "danger" => "text-danger hover:bg-danger/10 hover:text-danger-hover"
    }

    assigns = assign(assigns, :tone_class, Map.fetch!(tones, assigns.tone))

    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex shrink-0 items-center justify-center rounded-control p-2.5 transition-colors",
        focus_ring(),
        @tone_class,
        @class
      ]}
      {@rest}
    >
      <.icon name={@name} class="size-5" />
      <span class="sr-only">{@sr_label}</span>
    </button>
    """
  end

  @doc """
  Renders the actions row at the end of a form.

  ## Examples

      <.form_actions>
        <.button variant="primary">Save</.button>
      </.form_actions>
  """
  attr :align, :string, default: "start", values: ~w(start end)
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def form_actions(assigns) do
    ~H"""
    <footer class={[
      "flex flex-wrap items-center gap-3",
      @align == "end" && "justify-end",
      @class
    ]}>
      {render_slot(@inner_block)}
    </footer>
    """
  end

  ## Forms

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * `type="toggle"` renders a boolean as a switch

    * `type="checkgroup"` renders a list of `options` as toggleable chips,
      submitting the checked values as a list (`value` is the list of selected values)

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox checkgroup color date datetime-local email file month number password
               search select tel text textarea time toggle url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "extra classes for the input element"

  attr :sr_only, :boolean,
    default: false,
    doc: "visually hide the label, keeping it for screen readers"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        HTMLForm.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div>
      <label for={@id} class="inline-flex items-center gap-2 text-sm text-fg">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={["size-4 rounded-sm accent-primary", @class]}
          {@rest}
        />{@label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "toggle"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        HTMLForm.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div>
      <div class="flex items-center justify-between gap-3 rounded-control bg-surface px-4 py-3 inset-ring inset-ring-border">
        <label :if={@label} id={"#{@id}-label"} for={@id} class="text-sm font-medium text-fg">
          {@label}
        </label>
        <div class="group relative inline-flex w-11 shrink-0 rounded-full bg-surface-raised p-0.5 inset-ring inset-ring-border outline-offset-2 outline-primary transition-colors duration-200 ease-in-out has-checked:bg-primary has-focus-visible:outline-2">
          <span class="size-5 rounded-full bg-white shadow-xs transition-transform duration-200 ease-in-out group-has-checked:translate-x-5">
          </span>
          <input
            type="hidden"
            name={@name}
            value="false"
            disabled={@rest[:disabled]}
            form={@rest[:form]}
          />
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            aria-labelledby={"#{@id}-label"}
            class="absolute inset-0 size-full cursor-pointer appearance-none focus:outline-hidden"
            {@rest}
          />
        </div>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "checkgroup"} = assigns) do
    selected = assigns.value |> List.wrap() |> Enum.map(&to_string/1)
    assigns = assign(assigns, :selected, selected)

    ~H"""
    <fieldset>
      <legend :if={@label} class={["mb-1.5 text-sm font-medium text-fg", @sr_only && "sr-only"]}>
        {@label}
      </legend>
      <input type="hidden" name={@name} value="" />
      <div class="flex flex-wrap gap-2">
        <label
          :for={{option_label, option_value} <- @options}
          class={[
            "cursor-pointer rounded-full px-3 py-1.5 text-sm font-medium text-fg-muted transition-colors select-none",
            "inset-ring inset-ring-border-strong hover:text-fg",
            "has-checked:bg-primary has-checked:text-on-primary has-checked:inset-ring-primary",
            "has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-primary"
          ]}
        >
          <input
            type="checkbox"
            name={@name}
            value={option_value}
            checked={to_string(option_value) in @selected}
            class="sr-only"
            {@rest}
          />
          {option_label}
        </label>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  def input(%{type: "select"} = assigns) do
    assigns = assign(assigns, field_class: @field_class, field_error_class: @field_error_class)

    ~H"""
    <div>
      <.label :if={@label} for={@id} sr_only={@sr_only}>{@label}</.label>
      <div class="grid grid-cols-1">
        <select
          id={@id}
          name={@name}
          class={[
            "col-start-1 row-start-1 pr-10",
            @field_class,
            @errors != [] && @field_error_class,
            @value in ["", nil] && "text-fg-subtle",
            @class
          ]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
        <.icon
          name="hero-chevron-down-mini"
          class="pointer-events-none col-start-1 row-start-1 mr-3 size-5 self-center justify-self-end text-fg-muted sm:size-4"
        />
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    assigns =
      assign(assigns,
        field_class: @field_class,
        text_field_class: @text_field_class,
        field_error_class: @field_error_class
      )

    ~H"""
    <div>
      <.label :if={@label} for={@id} sr_only={@sr_only}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        class={[@field_class, @text_field_class, @errors != [] && @field_error_class, @class]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    assigns =
      assign(assigns,
        field_class: @field_class,
        text_field_class: @text_field_class,
        field_error_class: @field_error_class
      )

    ~H"""
    <div>
      <.label :if={@label} for={@id} sr_only={@sr_only}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[@field_class, @text_field_class, @errors != [] && @field_error_class, @class]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a form label. Used by `input/1`; use it directly for custom controls.

  ## Examples

      <.label for="player-autocomplete">Jogador</.label>
  """
  attr :for, :string, default: nil
  attr :sr_only, :boolean, default: false
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class={["mb-1.5 block text-sm font-medium text-fg", @sr_only && "sr-only"]}>
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Returns the classes of a text field, for custom controls that must look like `input/1`.
  """
  def field_class, do: @field_class

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex items-center gap-1.5 text-sm text-danger">
      <.icon name="hero-exclamation-circle-mini" class="size-4 shrink-0" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  ## Layout & content

  @doc """
  Renders the page header with title.
  """
  attr :class, :any, default: nil
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={["mb-8 flex flex-wrap items-end justify-between gap-4", @class]}>
      <div class="min-w-0">
        <h1 class="font-display text-2xl font-bold tracking-tight text-fg">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-1 text-sm text-fg-muted">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div :if={@actions != []} class="flex flex-wrap items-center gap-2">
        {render_slot(@actions)}
      </div>
    </header>
    """
  end

  @doc """
  Renders a section title (an `h2`) with optional actions.

  ## Examples

      <.section_title>
        Mesas
        <:actions><.button>Add</.button></:actions>
      </.section_title>
  """
  attr :class, :any, default: nil
  slot :inner_block, required: true
  slot :actions

  def section_title(assigns) do
    ~H"""
    <div class={["flex items-center justify-between gap-4", @class]}>
      <h2 class="font-display text-lg font-semibold text-fg">{render_slot(@inner_block)}</h2>
      <div :if={@actions != []} class="flex items-center gap-2">{render_slot(@actions)}</div>
    </div>
    """
  end

  @doc """
  Renders a surface container.

  ## Examples

      <.card>Content</.card>
      <.card padded={false}><header>...</header></.card>
      <ul><.card :for={item <- @items} tag="li">{item.name}</.card></ul>
  """
  attr :tag, :string, default: "div", doc: "the HTML tag to render, e.g. `li` inside lists"
  attr :padded, :boolean, default: true
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={@tag}
      class={[
        "rounded-card bg-surface shadow-lg shadow-black/20 inset-ring inset-ring-border",
        @padded && "p-4",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.dynamic_tag>
    """
  end

  @doc """
  Renders a modal dialog.

  Visibility is controlled by the caller (typically with `:if`), and `on_close`
  is triggered by the close button, a click on the backdrop, or the Escape key.

  ## Examples

      <.modal :if={@editing} id="edit-modal" title="Edit" on_close="close_modal">
        ...
      </.modal>
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :on_close, :any, required: true, doc: "event name or `JS` command"
  attr :class, :any, default: "max-w-md"
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      role="dialog"
      aria-modal="true"
      aria-labelledby={"#{@id}-title"}
      class="fixed inset-0 z-50 overflow-y-auto"
      phx-window-keydown={@on_close}
      phx-key="escape"
    >
      <div class="fixed inset-0 bg-scrim" aria-hidden="true" phx-click={@on_close}></div>
      <div class="pointer-events-none relative flex min-h-full items-end justify-center p-4 sm:items-center">
        <div class={[
          "pointer-events-auto w-full rounded-card bg-overlay p-6 shadow-2xl inset-ring inset-ring-border",
          @class
        ]}>
          <div class="mb-5 flex items-start justify-between gap-4">
            <h2 id={"#{@id}-title"} class="font-display text-lg font-semibold text-fg">
              {@title}
            </h2>
            <.icon_button
              name="hero-x-mark-mini"
              sr_label={gettext("Close")}
              class="-m-2.5"
              phx-click={@on_close}
            />
          </div>
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a small status label.

  ## Examples

      <.badge tone="gold">Campeão</.badge>
  """
  attr :tone, :string,
    default: "neutral",
    values: ~w(neutral primary success warning danger gold silver bronze)

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def badge(assigns) do
    tones = %{
      "neutral" => "bg-fg/10 text-fg",
      "primary" => "bg-primary/15 text-primary",
      "success" => "bg-success/15 text-success",
      "warning" => "bg-warning/15 text-warning",
      "danger" => "bg-danger/15 text-danger",
      "gold" => "bg-gold/15 text-gold",
      "silver" => "bg-silver/20 text-fg",
      "bronze" => "bg-bronze/20 text-fg"
    }

    assigns = assign(assigns, :tone_class, Map.fetch!(tones, assigns.tone))

    ~H"""
    <span
      class={[
        "inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium whitespace-nowrap",
        @tone_class,
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Renders a horizontal tab navigation.

  ## Examples

      <.tabs label="Tabs">
        <:tab patch={~p"/?tab=a"} active={@tab == "a"}>A</:tab>
        <:tab patch={~p"/?tab=b"} active={@tab == "b"}>B</:tab>
      </.tabs>
  """
  attr :label, :string, required: true, doc: "accessible name of the navigation"
  attr :class, :any, default: nil, doc: "extra classes for the nav (e.g. horizontal padding)"

  slot :tab, required: true do
    attr :patch, :string, required: true
    attr :active, :boolean
  end

  slot :inner_block, doc: "trailing content after the tabs, e.g. an add button"

  def tabs(assigns) do
    ~H"""
    <div class="relative overflow-x-auto border-b border-border">
      <nav aria-label={@label} class={["flex gap-6 whitespace-nowrap", @class]}>
        <.link
          :for={tab <- @tab}
          patch={tab.patch}
          aria-current={tab[:active] && "page"}
          class={[
            "shrink-0 border-b-2 py-3 text-sm font-medium transition-colors",
            if(tab[:active],
              do: "border-primary text-primary",
              else: "border-transparent text-fg-muted hover:border-border-strong hover:text-fg"
            )
          ]}
        >
          {render_slot(tab)}
        </.link>
        {render_slot(@inner_block)}
      </nav>
    </div>
    """
  end

  @doc """
  Renders a labelled horizontal bar showing `value` relative to `max`.

  ## Examples

      <.meter label="Sub-15" value={12} max={20} />
      <.meter label="Pendentes" value={3} max={20} tone="warning" />
  """
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :max, :integer, required: true
  attr :tone, :string, default: "primary", values: ~w(primary success warning)

  def meter(assigns) do
    tones = %{
      "primary" => "bg-primary-strong",
      "success" => "bg-success-strong",
      "warning" => "bg-warning-strong"
    }

    pct = if assigns.max > 0, do: round(assigns.value / assigns.max * 100), else: 0
    assigns = assign(assigns, pct: pct, tone_class: Map.fetch!(tones, assigns.tone))

    ~H"""
    <div class="flex items-center gap-3">
      <span class="w-28 shrink-0 truncate text-sm text-fg-muted">{@label}</span>
      <div
        role="meter"
        aria-label={@label}
        aria-valuenow={@value}
        aria-valuemin="0"
        aria-valuemax={@max}
        class="h-2 flex-1 overflow-hidden rounded-full bg-surface-raised"
      >
        <div class={["h-full rounded-full", @tone_class]} style={"width: #{@pct}%"}></div>
      </div>
      <span class="w-8 text-right text-sm text-fg tabular-nums">{@value}</span>
    </div>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="relative overflow-x-auto rounded-card bg-surface/60 inset-ring inset-ring-border">
      <table class="min-w-full">
        <thead>
          <tr>
            <th
              :for={col <- @col}
              class="px-4 py-3 text-left text-xs font-medium tracking-wide text-fg-muted uppercase"
            >
              {col[:label]}
            </th>
            <th :if={@action != []}>
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="border-t border-border transition-colors hover:bg-fg/5"
          >
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={["px-4 py-3 text-sm text-fg", @row_click && "hover:cursor-pointer"]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="w-0 px-4 py-3">
              <div class="flex justify-end gap-4 text-sm font-medium whitespace-nowrap text-primary">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="divide-y divide-border rounded-card bg-surface/60 inset-ring inset-ring-border">
      <li :for={item <- @item} class="grid gap-1 px-4 py-3 sm:grid-cols-3 sm:gap-4">
        <div class="text-sm font-medium text-fg-muted">{item.title}</div>
        <div class="text-sm text-fg sm:col-span-2">{render_slot(item)}</div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} aria-hidden="true" />
    """
  end

  defp focus_ring, do: @focus_ring

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(T3SystemWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(T3SystemWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
