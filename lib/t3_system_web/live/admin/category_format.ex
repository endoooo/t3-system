defmodule T3SystemWeb.Admin.CategoryFormat do
  @moduledoc """
  Shared display helpers for category formats.
  """
  use Gettext, backend: T3SystemWeb.Gettext

  alias T3System.Categories.Category

  @doc "Human label for a category format."
  @spec format_label(String.t()) :: String.t()
  def format_label("singles"), do: gettext("Simples")
  def format_label("doubles"), do: gettext("Duplas")

  @doc "Select options for the category format picker."
  @spec format_options() :: [{String.t(), String.t()}]
  def format_options do
    Enum.map(Category.formats(), &{format_label(&1), &1})
  end
end
