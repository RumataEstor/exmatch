defmodule ExMatch.Use do
  def setup(opts, caller) do
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

    preface = remove_imports([{name, 1}], caller)

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

  defp remove_imports(funs, %Macro.Env{} = caller) do
    funs
    |> find_imports(caller)
    |> Enum.uniq()
    |> Enum.group_by(fn {module, _} -> module end, fn {_, fun} -> fun end)
    |> Enum.map(fn {module, funs} ->
      quote do
        import unquote(module), except: unquote(funs)
      end
    end)
  end

  # This is used only in Elixir < 1.13
  defp find_imports_manually(funs, caller) do
    %Macro.Env{functions: functions, macros: macros} = caller
    funs = MapSet.new(funs)

    Enum.reduce(functions ++ macros, [], fn {module, imports}, results ->
      Enum.reduce(imports, results, fn imported, results ->
        if MapSet.member?(funs, imported) do
          [{module, imported} | results]
        else
          results
        end
      end)
    end)
  end

  # Only in Elixir >= 1.13
  if function_exported?(Macro.Env, :lookup_import, 2) do
    defp find_imports(funs, caller) do
      if function_exported?(Macro.Env, :lookup_import, 2) do
        Enum.flat_map(funs, fn fun ->
          caller
          |> Macro.Env.lookup_import(fun)
          |> Enum.map(fn {_, module} -> {module, fun} end)
        end)
      else
        find_imports_manually(funs, caller)
      end
    end
  else
    defp find_imports(fun, caller),
      do: find_imports_manually(fun, caller)
  end
end
