defmodule Airthings.Utilities do
  @doc """
  Transforms a map's key by applying the key update function to the key name and type
  and applying the value update function to the key's value
  """
  @spec transform(map, Map.key(), (any -> any), (any -> any)) :: map
  def transform(map, key, key_update_fn, value_update_fn) do
    if Map.has_key?(map, key) do
      new_value =
        map
        |> Map.get(key)
        |> value_update_fn.()

      new_key = key_update_fn.(key)

      map
      |> Map.delete(key)
      |> Map.put(new_key, new_value)
    else
      map
    end
  end

  @doc """
  Converts a map to the given module's struct. This is helpful over the built in
  `Kernel.struct` since a map can be piped into it.
  """
  @spec to_struct(map, module) :: struct
  def to_struct(map, module) do
    struct(module, map)
  end
end
