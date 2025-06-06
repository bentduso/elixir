# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

Code.require_file("../test_helper.exs", __DIR__)

defmodule Kernel.RaiseTest do
  use ExUnit.Case, async: true

  # Silence warnings
  defp atom, do: RuntimeError
  defp binary, do: "message"
  defp opts, do: [message: "message"]
  defp struct, do: %RuntimeError{message: "message"}

  @compile {:no_warn_undefined, DoNotExist}
  @trace [{:foo, :bar, 0, []}]

  test "raise preserves the stacktrace" do
    stacktrace =
      try do
        raise "a"
      rescue
        _ -> Enum.fetch!(__STACKTRACE__, 0)
      end

    file = __ENV__.file |> Path.relative_to_cwd() |> String.to_charlist()

    assert {__MODULE__, :"test raise preserves the stacktrace", _, [file: ^file, line: 22] ++ _} =
             stacktrace
  end

  test "raise message" do
    assert_raise RuntimeError, "message", fn ->
      raise "message"
    end

    assert_raise RuntimeError, "message", fn ->
      var = binary()
      raise var
    end
  end

  test "raise with no arguments" do
    assert_raise RuntimeError, fn ->
      raise RuntimeError
    end

    assert_raise RuntimeError, fn ->
      var = atom()
      raise var
    end
  end

  test "raise with arguments" do
    assert_raise RuntimeError, "message", fn ->
      raise RuntimeError, message: "message"
    end

    assert_raise RuntimeError, "message", fn ->
      atom = atom()
      opts = opts()
      raise atom, opts
    end
  end

  test "raise existing exception" do
    assert_raise RuntimeError, "message", fn ->
      raise %RuntimeError{message: "message"}
    end

    assert_raise RuntimeError, "message", fn ->
      var = struct()
      raise var
    end
  end

  test "raise with error_info" do
    {exception, stacktrace} =
      try do
        raise "a"
      rescue
        e -> {e, __STACKTRACE__}
      end

    assert [{__MODULE__, _, _, meta} | _] = stacktrace
    assert meta[:error_info] == %{module: Exception}

    assert Exception.format_error(exception, stacktrace) ==
             %{general: "a", reason: "#Elixir.RuntimeError"}
  end

  test "reraise message" do
    try do
      reraise "message", @trace
      flunk("should not reach")
    rescue
      RuntimeError ->
        assert @trace == __STACKTRACE__
    end

    try do
      var = binary()
      reraise var, @trace
      flunk("should not reach")
    rescue
      RuntimeError ->
        assert @trace == __STACKTRACE__
    end
  end

  test "reraise with no arguments" do
    try do
      reraise RuntimeError, @trace
      flunk("should not reach")
    rescue
      RuntimeError ->
        assert @trace == __STACKTRACE__
    end

    try do
      var = atom()
      reraise var, @trace
      flunk("should not reach")
    rescue
      RuntimeError ->
        assert @trace == __STACKTRACE__
    end
  end

  test "reraise with arguments" do
    try do
      reraise RuntimeError, [message: "message"], @trace
      flunk("should not reach")
    rescue
      RuntimeError ->
        assert @trace == __STACKTRACE__
    end

    try do
      atom = atom()
      opts = opts()
      reraise atom, opts, @trace
      flunk("should not reach")
    rescue
      RuntimeError ->
        assert @trace == __STACKTRACE__
    end
  end

  test "reraise existing exception" do
    try do
      reraise %RuntimeError{message: "message"}, @trace
      flunk("should not reach")
    rescue
      RuntimeError ->
        assert @trace == __STACKTRACE__
    end

    try do
      var = struct()
      reraise var, @trace
      flunk("should not reach")
    rescue
      RuntimeError ->
        assert @trace == __STACKTRACE__
    end
  end

  describe "rescue" do
    test "runtime error" do
      result =
        try do
          raise "an exception"
        rescue
          RuntimeError -> true
        catch
          :error, _ -> false
        end

      assert result

      result =
        try do
          raise "an exception"
        rescue
          ArgumentError -> true
        catch
          :error, _ -> false
        end

      refute result
    end

    test "named runtime error" do
      result =
        try do
          raise "an exception"
        rescue
          x in [RuntimeError] -> Exception.message(x)
        catch
          :error, _ -> false
        end

      assert result == "an exception"
    end

    test "named runtime or argument error" do
      result =
        try do
          raise "an exception"
        rescue
          x in [ArgumentError, RuntimeError] -> Exception.message(x)
        catch
          :error, _ -> false
        end

      assert result == "an exception"
    end

    test "named function clause (stacktrace) or runtime (no stacktrace) error" do
      result =
        try do
          Access.get("foo", 0)
        rescue
          x in [FunctionClauseError, CaseClauseError] -> Exception.message(x)
        end

      assert result == "no function clause matching in Access.get/3"
    end

    test "with higher precedence than catch" do
      result =
        try do
          raise "an exception"
        rescue
          _ -> true
        catch
          _, _ -> false
        end

      assert result
    end

    test "argument error from Erlang" do
      result =
        try do
          :erlang.error(:badarg)
        rescue
          ArgumentError -> true
        end

      assert result
    end

    test "argument error from Elixir" do
      result =
        try do
          raise ArgumentError, ""
        rescue
          ArgumentError -> true
        end

      assert result
    end

    test "catch-all variable" do
      result =
        try do
          raise "an exception"
        rescue
          x -> Exception.message(x)
        end

      assert result == "an exception"
    end

    test "catch-all underscore" do
      result =
        try do
          raise "an exception"
        rescue
          _ -> true
        end

      assert result
    end

    test "catch-all unused variable" do
      result =
        try do
          raise "an exception"
        rescue
          _any -> true
        end

      assert result
    end

    test "catch-all with \"x in _\" syntax" do
      result =
        try do
          raise "an exception"
        rescue
          exception in _ ->
            Exception.message(exception)
        end

      assert result == "an exception"
    end

    defmacrop argerr(e) do
      quote(do: unquote(e) in ArgumentError)
    end

    test "with rescue macro" do
      result =
        try do
          raise ArgumentError, "oops, badarg"
        rescue
          argerr(e) -> Exception.message(e)
        end

      assert result == "oops, badarg"
    end
  end

  describe "normalize" do
    test "wrap custom Erlang error" do
      result =
        try do
          :erlang.error(:sample)
        rescue
          x in [ErlangError] -> Exception.message(x)
        end

      assert result == "Erlang error: :sample"
    end

    test "undefined function error" do
      result =
        try do
          DoNotExist.for_sure()
        rescue
          x in [UndefinedFunctionError] -> Exception.message(x)
        end

      assert result ==
               "function DoNotExist.for_sure/0 is undefined (module DoNotExist is not available). " <>
                 "Make sure the module name is correct and has been specified in full (or that an alias has been defined)"
    end

    test "function clause error" do
      result =
        try do
          Access.get(:ok, :error)
        rescue
          x in [FunctionClauseError] -> Exception.message(x)
        end

      assert result == "no function clause matching in Access.get/3"
    end

    test "badarg error" do
      result =
        try do
          :erlang.error(:badarg)
        rescue
          x in [ArgumentError] -> Exception.message(x)
        end

      assert result == "argument error"
    end

    test "tuple badarg error" do
      result =
        try do
          :erlang.error({:badarg, [1, 2, 3]})
        rescue
          x in [ArgumentError] -> Exception.message(x)
        end

      assert result == "argument error: [1, 2, 3]"
    end

    test "badarith error" do
      result =
        try do
          :erlang.error(:badarith)
        rescue
          x in [ArithmeticError] -> Exception.message(x)
        end

      assert result == "bad argument in arithmetic expression"
    end

    test "badarity error" do
      fun = fn x -> x end
      string = "#{inspect(fun)} with arity 1 called with 2 arguments (1, 2)"

      result =
        try do
          Process.get(:unused, fun).(1, 2)
        rescue
          x in [BadArityError] -> Exception.message(x)
        end

      assert result == string
    end

    test "badfun error" do
      # Avoid "invalid function call" warning
      x = fn -> :example end

      result =
        try do
          x.().(2)
        rescue
          x in [BadFunctionError] -> Exception.message(x)
        end

      assert result == "expected a function, got: :example"
    end

    test "badfun error when the function is gone" do
      defmodule BadFunction.Missing do
        def fun, do: fn -> :ok end
      end

      fun = BadFunction.Missing.fun()

      :code.purge(BadFunction.Missing)
      :code.delete(BadFunction.Missing)

      defmodule BadFunction.Missing do
        def fun, do: fn -> :another end
      end

      :code.purge(BadFunction.Missing)

      try do
        fun.()
      rescue
        x in [BadFunctionError] ->
          assert Exception.message(x) =~
                   ~r/function #Function<[0-9]\.[0-9]*\/0[^>]*> is invalid, likely because it points to an old version of the code/
      else
        _ -> flunk("this should not be invoked")
      end
    end

    test "badmatch error" do
      result =
        try do
          [] = Range.to_list(1000_000..1_000_009)
        rescue
          x in [MatchError] -> Exception.message(x)
        end

      assert result ==
               """
               no match of right hand side value:

                   [1000000, 1000001, 1000002, 1000003, 1000004, 1000005, 1000006, 1000007,
                    1000008, 1000009]\
               """
    end

    test "bad key error" do
      result =
        try do
          %{Process.get(:unused, %{}) | foo: :bar}
        rescue
          x in [KeyError] -> Exception.message(x)
        end

      assert result == "key :foo not found"

      result =
        try do
          Process.get(:unused, %{}).foo
        rescue
          x in [KeyError] -> Exception.message(x)
        end

      assert result == "key :foo not found in:\n\n    %{}"
    end

    test "bad map error" do
      result =
        try do
          %{Process.get(:unused, 0) | foo: :bar}
        rescue
          x in [BadMapError] -> Exception.message(x)
        end

      assert result == "expected a map, got:\n\n    0"
    end

    test "bad boolean error" do
      result =
        try do
          Process.get(:unused, 1) and true
        rescue
          x in [BadBooleanError] -> Exception.message(x)
        end

      assert result == "expected a boolean on left-side of \"and\", got:\n\n    1"
    end

    test "case clause error" do
      x = :example

      result =
        try do
          case Process.get(:unused, 0) do
            ^x -> nil
          end
        rescue
          x in [CaseClauseError] -> Exception.message(x)
        end

      assert result == "no case clause matching:\n\n    0"
    end

    test "cond clause error" do
      result =
        try do
          cond do
            !Process.get(:unused, 0) -> :ok
          end
        rescue
          x in [CondClauseError] -> Exception.message(x)
        end

      assert result == "no cond clause evaluated to a truthy value"
    end

    test "try clause error" do
      f = fn -> :example end

      result =
        try do
          try do
            f.()
          rescue
            _exception ->
              :ok
          else
            :other ->
              :ok
          end
        rescue
          x in [TryClauseError] -> Exception.message(x)
        end

      assert result == "no try clause matching:\n\n    :example"
    end

    test "undefined function error as Erlang error" do
      result =
        try do
          DoNotExist.for_sure()
        rescue
          x in [ErlangError] -> Exception.message(x)
        end

      assert result ==
               "function DoNotExist.for_sure/0 is undefined (module DoNotExist is not available). " <>
                 "Make sure the module name is correct and has been specified in full (or that an alias has been defined)"
    end
  end

  defmacrop exceptions do
    [ErlangError]
  end

  test "with macros" do
    result =
      try do
        DoNotExist.for_sure()
      rescue
        x in exceptions() -> Exception.message(x)
      end

    assert result ==
             "function DoNotExist.for_sure/0 is undefined (module DoNotExist is not available). " <>
               "Make sure the module name is correct and has been specified in full (or that an alias has been defined)"
  end
end
