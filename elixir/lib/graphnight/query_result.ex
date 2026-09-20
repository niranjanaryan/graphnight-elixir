defmodule GraphNight.QueryResult do
  @moduledoc """
  Represents the result of a GraphNight query execution.
  """
  @enforce_keys [:data, :columns, :sql, :execution_time_ms]
  defstruct [
    :data,
    :columns,
    :sql,
    :execution_time_ms
  ]
end