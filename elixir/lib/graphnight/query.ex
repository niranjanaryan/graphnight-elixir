defmodule GraphNight.Query do
  @moduledoc """
  Represents a query to execute against GraphNight.
  """
  defstruct [
    :name,
    :source_model,
    :measures,
    :dimensions,
    :time_dimensions,
    :filters,
    :order,
    :limit,
    :offset,
    :whole_periods_only,
    :distinct_dimension_values,
    :stage_ref
  ]


  def new(opts \\ []) do
    %__MODULE__{
      name: Keyword.get(opts, :name),
      source_model: Keyword.get(opts, :source_model),
      measures: Keyword.get(opts, :measures, []),
      dimensions: Keyword.get(opts, :dimensions, []),
      time_dimensions: Keyword.get(opts, :time_dimensions, []),
      filters: Keyword.get(opts, :filters, []),
      order: Keyword.get(opts, :order, []),
      limit: Keyword.get(opts, :limit),
      offset: Keyword.get(opts, :offset),
      whole_periods_only: Keyword.get(opts, :whole_periods_only),
      distinct_dimension_values: Keyword.get(opts, :distinct_dimension_values),
      stage_ref: Keyword.get(opts, :stage_ref)
    }
  end
end