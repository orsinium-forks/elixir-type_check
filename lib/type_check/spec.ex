defmodule TypeCheck.Spec do
  defmacro __before_compile__(env) do
    IO.inspect(env)
    typedefs = Module.get_attribute(env.module, TypeCheck.Spec.Raw)

    types = typedefs |> Enum.filter(fn {key, val} -> val.kind in [:type, :typep, :opaque] end)
    specs = typedefs |> Enum.filter(fn {key, val} -> val.kind == :spec end)
    IO.inspect(types)
    IO.inspect(specs)
    type_res = eval_types(types)
    spec_res = eval_specs(specs)
    quote do
    end
  end

  defp eval_types(types) do
    Enum.map(types, &eval_type/1)
  end

  defp eval_type(type) do
    :ok
  end

  defp eval_specs(specs) do
    Enum.map(specs, &eval_spec/1)
  end

  defp eval_spec(spec) do
    :ok
  end

  defmacro type(args) do
    build_typedef_ast(args, :type)
  end

  defmacro typep(args) do
    build_typedef_ast(args, :typep)
  end

  defmacro opaque(args) do
    build_typedef_ast(args, :opaque)
  end

  defmacro spec(args) do
    build_spec_ast(args)
  end

  # Shared between type, typep and opaque
  defp build_typedef_ast(args, call_kind) do
    {name, raw_type} = extract_type_name(args)
    quote do
      Module.put_attribute(__MODULE__, TypeCheck.Spec.Raw, {unquote(name), %{kind: unquote(call_kind), type: unquote(Macro.escape(raw_type))}})
    end
  end

  defp build_spec_ast(args) do
    {name, arg_types, return_type} = extract_spec_name(args)
    quote do
      Module.put_attribute(__MODULE__, TypeCheck.Spec.Raw, {unquote(name), %{kind: :spec, arg_types: unquote(Macro.escape(arg_types)), type: unquote(Macro.escape(return_type))}})
    end
  end

  defp extract_type_name(ast = {:"::", _, [name, type]}) do
    case extract_var_name(name) do
      {:ok, var} ->
        {var, type}
      :error ->
        raise "Expected type name to be a variable, but got `#{Macro.to_string(name)}` while parsing #{Macro.to_string(ast)}"
    end
  end
  defp extract_type_name(other) do
    raise "Expected a definition in the shape of `name :: type` but got `#{Macro.to_string(other)}`"
  end

  defp extract_spec_name(ast = {:"::", _, [{function_name, _, arg_types}, return_type]}) when is_atom(function_name) and is_list(arg_types) do
    {function_name, arg_types, return_type}
  end

  defp extract_var_name({name, _, module}) when is_atom(name) and is_atom(module), do: {:ok, name}
  defp extract_var_name(_), do: :error
end