defmodule TypeCheck.Builtin.Float do
  defstruct []

  defimpl TypeCheck.Protocols.ToCheck do
    def to_check(s, param) do
      quote do
        case unquote(param) do
          x when is_float(x) ->
            :ok
          _ ->
            {:error, {unquote(Macro.escape(s)), :not_a_float, %{}, unquote(param)}}
        end
      end
    end
  end

  defimpl TypeCheck.Protocols.Inspect do
    def inspect(_, _opts) do
      "float()"
    end
  end
end