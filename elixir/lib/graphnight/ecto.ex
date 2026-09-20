defmodule GraphNight.Ecto do
  @moduledoc """
  Ecto integration for GraphNight (simplified).
  
  Provides basic helpers for converting GraphNight models to Ecto schemas.
  """

  @doc """
  Convert a GraphNight Model to an Ecto Schema module definition.
  """
  def model_to_ecto_schema(model, opts \\ []) do
    table_name = Keyword.get(opts, :table_name, model.name)
    primary_key = Keyword.get(opts, :primary_key, :id)
    
    dimension_fields = Enum.map(model.dimensions, fn dim ->
      "field :#{dim.name}, :string"
    end)
    
    time_fields = Enum.map(model.time_dimensions, fn td ->
      "field :#{td.dimension}, :utc_datetime"
    end)
    
    measure_fields = Enum.map(model.measures, fn measure ->
      "# measure: #{measure.formula} (#{measure.aggregation})"
    end)
    
    all_fields = dimension_fields ++ time_fields ++ measure_fields
    
    schema_code = """
    defmodule #{String.capitalize(table_name)} do
      use Ecto.Schema
      
      @primary_key {:#{primary_key}, :id, autogenerate: true}
      schema \"#{table_name}\" do
        #{Enum.join(all_fields, "\n        ")}
        
        timestamps()
      end
    end
    """
    
    schema_code
  end
end