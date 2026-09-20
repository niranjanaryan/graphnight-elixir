defmodule GraphNight.Dimension do
  @moduledoc """
  Represents a dimension in a GraphNight model.
  """
  @enforce_keys [:name]
  defstruct [
    :name,
    :label
  ]


  def new(name, opts \\ []) do
    %__MODULE__{
      name: name,
      label: Keyword.get(opts, :label)
    }
  end
end