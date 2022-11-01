defmodule ExMatch do
  @external_resource "README.md"

  @moduledoc """
  Assertions for data equivalence.

  #{"README.md" |> File.read!() |> String.split("<!-- EXAMPLES -->") |> Enum.at(1)}
  """

  @assertion_error (if Mix.env() in [:test] do
                      ExMatchTest.AssertionError
                    else
                      ExUnit.AssertionError
                    end)

  alias ExMatch.ParseContext

  defmacro __using__(opts) do
    name = Keyword.get(opts, :as, :exmatch)
    public = Keyword.get(opts, :pub, false)

    if not is_atom(name) do
      raise "'as' must be an atom, got #{inspect(name)}"
    end

    if not is_boolean(public) do
      raise "'pub' must be a boolean, got #{inspect(public)}"
    end

    opts =
      opts
      |> Keyword.get(:opts, [])
      |> ExMatch.Options.parse()

    preface = remove_imports([{name, 1}], __CALLER__)

    opts_fun_suffix = :crypto.strong_rand_bytes(5) |> Base.encode32()
    opts_fun_name = :"exmatch_fun_#{opts_fun_suffix}"

    quote location: :keep do
      unquote(preface)

      defp unquote(opts_fun_name)() do
        unquote(opts)
      end

      defmacrop unquote(name)(left, right) do
        opts_fun_name = unquote(opts_fun_name)

        quote location: :keep do
          ExMatch.match(unquote(left), unquote(right), unquote(opts_fun_name)())
        end
      end

      defmacrop unquote(name)(expr) do
        opts_fun_name = unquote(opts_fun_name)

        quote location: :keep do
          ExMatch.match(unquote(expr), unquote(opts_fun_name)())
        end
      end
    end
  end

  defp remove_imports(funs, caller) do
    funs
    |> Enum.flat_map(fn fun ->
      caller
      |> Macro.Env.lookup_import(fun)
      |> Enum.map(fn {_, module} -> {module, fun} end)
    end)
    |> Enum.uniq()
    |> Enum.group_by(fn {module, _} -> module end, fn {_, fun} -> fun end)
    |> Enum.map(fn {module, funs} ->
      quote do
        import unquote(module), except: unquote(funs)
      end
    end)
  end

  defmacro match(expr) do
    gen_match(expr, quote(do: ExMatch.default_options()))
  end

  @doc """
  Raises if the values don't match and displays what exactly was different.

  iex> ExMatch.match([1, a, 3], [1, 2, 3])
  iex> 2 = a
  """
  defmacro match(arg1, arg2) do
    gen_match(arg1, arg2)
  end

  defmacro match(left, right, opts) do
    gen_match(left, right, parse_options(opts))
  end

  defmacro options(item) do
    parse_options(item)
  end

  defp parse_options(item) do
    ExMatch.Options.parse(item)
  end

  def default_options() do
    options([])
  end

  defp gen_match({:==, _, [left, right]}, opts) do
    gen_match(left, right, opts)
  end

  defp gen_match({:=, _, [left, right]}, opts) do
    gen_match(left, right, opts)
  end

  defp gen_match(arg1, arg2) do
    right =
      quote do
        case unquote(arg2) do
          %ExMatch.Options{} ->
            raise "The pattern #{unquote(Macro.to_string(arg1))} is not yet supported"

          value ->
            value
        end
      end

    gen_match(arg1, right, quote(do: ExMatch.default_options()))
  end

  def gen_match(left, right, opts_expr) do
    opts_var = Macro.var(:opts, __MODULE__)
    parse_context = %ParseContext{opts: opts_var}
    {bindings, left} = ParseContext.parse(left, parse_context)

    quote location: :keep do
      right = unquote(right)

      unquote(opts_var) =
        case unquote(opts_expr) do
          %ExMatch.Options{opts: opts} ->
            opts

          other ->
            raise "The options provided as #{unquote(Macro.to_string(opts_expr))} must be built using ExMatch.options/1, got #{inspect(other)}"
        end

      unquote(bindings) =
        case ExMatch.Match.diff(unquote(left), right, unquote(opts_var)) do
          {diff_left, diff_right} = diff ->
            raise unquote(@assertion_error),
              left: diff_left,
              right: diff_right,
              context: {:match, []}

          bindings when is_list(bindings) ->
            bindings
        end

      :ok
    end
  end
end
