defmodule ExMatchTest.TestCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      require ExMatch
      import ExMatchTest.TestCase
    end
  end

  defmacro sigil_m({:<<>>, _, [string]}, []) do
    decimal =
      string
      |> String.replace("_", "")
      |> Decimal.new()
      |> Macro.escape()

    quote do
      unquote(decimal)
    end
  end

  defmacro match_fails(expr, expected_message) do
    quote do
      result =
        try do
          unquote(expr)
          :ok
        rescue
          error in ExMatchTest.AssertionError ->
            error
        end

      if result == :ok do
        raise ExUnit.AssertionError, "expected to raise but returned successfully"
      end

      expected_message = unquote(expected_message)

      if is_binary(expected_message) do
        expected_message = String.trim_trailing(expected_message)
        assert expected_message == Exception.message(result)
      else
        expected_message.(Exception.message(result))
      end
    end
  end
end

defmodule ExMatchTest.AssertionError do
  # Unfortunately ExUnit.AssertionError.message/1 adds double newlines
  # to the output however doctests don't have a way to handle such exception
  # messages and therefore they cannot be verified in the doctests.
  #
  # Another inconsistency is that ExUnit.CLIFormatter uses its own code
  # to display differences in structs, so standard console and ExUnit tests
  # display diffs differently.

  @enforce_keys [:left, :right, :context]
  defexception @enforce_keys

  @impl true
  def message(self) do
    %__MODULE__{left: left, right: right, context: context} = self

    exception = %ExUnit.AssertionError{
      left: left,
      right: right,
      context: context
    }

    ExMatchTest.CLIFormatter.format_test_failure(exception)
  end
end

defmodule ExMatchTest.CLIFormatter do
  def format_test_failure(error) do
    tags = [file: ""]
    test = %ExUnit.Test{name: nil, module: __MODULE__, tags: tags}

    ExUnit.Formatter.format_test_failure(
      test,
      [{:error, error, []}],
      0,
      get_terminal_width(),
      &formatter(&1, &2, %{colors: [enabled: false]})
    )
    |> String.replace_leading("  0)  (ExMatchTest.CLIFormatter)\n     :\n     ", "")
    |> String.replace("\n     ", "\n")
    |> String.trim_trailing()
  end

  # copy from ExUnit.CLIFormatter
  defp get_terminal_width do
    case :io.columns() do
      {:ok, width} -> max(40, width)
      _ -> 80
    end
  end

  # copy from ExUnit.CLIFormatter
  defp formatter(:diff_enabled?, _, %{colors: colors}), do: colors[:enabled] || true

  defp formatter(:error_info, msg, config), do: colorize(:red, msg, config)

  defp formatter(:extra_info, msg, config), do: colorize(:cyan, msg, config)

  defp formatter(:location_info, msg, config), do: colorize([:bright, :black], msg, config)

  defp formatter(:diff_delete, doc, config), do: colorize_doc(:diff_delete, doc, config)

  defp formatter(:diff_delete_whitespace, doc, config),
    do: colorize_doc(:diff_delete_whitespace, doc, config)

  defp formatter(:diff_insert, doc, config), do: colorize_doc(:diff_insert, doc, config)

  defp formatter(:diff_insert_whitespace, doc, config),
    do: colorize_doc(:diff_insert_whitespace, doc, config)

  defp formatter(:blame_diff, msg, %{colors: colors} = config) do
    if colors[:enabled] do
      colorize(:red, msg, config)
    else
      "-" <> msg <> "-"
    end
  end

  defp formatter(_, msg, _config), do: msg

  # copy from ExUnit.CLIFormatter
  defp colorize(escape, string, %{colors: colors}) do
    if colors[:enabled] do
      [escape, string, :reset]
      |> IO.ANSI.format_fragment(true)
      |> IO.iodata_to_binary()
    else
      string
    end
  end

  # copy from ExUnit.CLIFormatter
  defp colorize_doc(escape, doc, %{colors: colors}) do
    if colors[:enabled] do
      Inspect.Algebra.color(doc, escape, %Inspect.Opts{syntax_colors: colors})
    else
      doc
    end
  end
end
