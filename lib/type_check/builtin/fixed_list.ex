defmodule TypeCheck.Builtin.FixedList do
  @moduledoc """
  Checks whether the value is a list with the expected elements

  On failure returns a problem tuple with:
    - `:not_a_list` if the value is not a list
    - `:different_length` if the value is a list but not of equal size.
    - `:element_error` if one of the elements does not match. The extra information contains in this case `:problem` and `:index` to indicate what and where the problem occured.
  """

  defstruct [:element_types]

  use TypeCheck
  @type! t :: %__MODULE__{element_types: list()}

  @type! problem_tuple ::
         {t(), :not_a_list, %{}, any()}
         | {t(), :different_length, %{expected_length: non_neg_integer()}, list()}
         | {t(), :element_error,
            %{problem: lazy(TypeCheck.TypeError.Formatter.problem_tuple()), index: integer()},
            list()}

  defimpl TypeCheck.Protocols.ToCheck do
    def to_check(s, param) do
      expected_length = length(s.element_types)
      element_checks_ast = build_element_checks_ast(s.element_types, param, s)

      quote do
        case unquote(param) do
          x when not is_list(x) ->
            {:error, {unquote(Macro.escape(s)), :not_a_list, %{}, x}}

          x when length(x) != unquote(expected_length) ->
            {:error,
             {unquote(Macro.escape(s)), :different_length,
              %{expected_length: unquote(expected_length)}, x}}

          _ ->
            unquote(element_checks_ast)
        end
      end
    end

    def build_element_checks_ast(element_types, param, s) do
      element_checks =
        element_types
        |> Enum.with_index()
        |> Enum.flat_map(fn {element_type, index} ->
          impl =
            TypeCheck.Protocols.ToCheck.to_check(
              element_type,
              quote do
                hd(var!(rest, unquote(__MODULE__)))
              end
            )

          quote location: :keep do
            [
              {{:ok, element_bindings}, index, var!(rest, unquote(__MODULE__))} <-
                {unquote(impl), unquote(index), tl(var!(rest, unquote(__MODULE__)))},
              bindings = element_bindings ++ bindings
            ]
          end
        end)

      quote location: :keep do
        bindings = []

        with var!(rest, unquote(__MODULE__)) = unquote(param), unquote_splicing(element_checks) do
          {:ok, bindings}
        else
          {{:error, error}, index, _rest} ->
            {:error,
             {unquote(Macro.escape(s)), :element_error, %{problem: error, index: index},
              unquote(param)}}
        end
      end
    end
  end

  defimpl TypeCheck.Protocols.Inspect do
    def inspect(s, opts) do
      s.element_types
      |> Elixir.Inspect.inspect(%Inspect.Opts{
        opts
        | inspect_fun: &TypeCheck.Protocols.Inspect.inspect/2
      })
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl TypeCheck.Protocols.ToStreamData do
      def to_gen(s) do
        s.element_types
        |> Enum.map(&TypeCheck.Protocols.ToStreamData.to_gen/1)
        |> StreamData.fixed_list()
      end
    end
  end
end
