defmodule ExMatchTest.UsePlain do
  use ExMatchTest.TestCase
  use ExMatch

  import ExMatchTest.TestCase, only: [match_fails: 2]

  test "exmatch _, _" do
    exmatch 1, 1

    match_fails(
      exmatch(1, 2),
      """
      left:  1
      right: 2
      """
    )
  end

  test "exmatch _ == _" do
    exmatch 1 == 1

    match_fails(
      exmatch(1 == 2),
      """
      left:  1
      right: 2
      """
    )
  end

  test "exmatch _ = _" do
    exmatch 1 = 1

    match_fails(
      exmatch(1 = 2),
      """
      left:  1
      right: 2
      """
    )
  end
end

defmodule ExMatchTest.UseAssert do
  use ExUnit.Case
  use ExMatch, as: :assert

  import ExMatchTest.TestCase, only: [match_fails: 2]

  test "assert _ == _" do
    m = %{a: 1, b: 2}
    assert %{..., a: 1} == m

    match_fails(
      assert(%{a: 1} == m),
      """
      left:  %{}
      right: %{b: 2}
      """
    )
  end

  test "exmatch _ = _" do
    m = %{a: 1, b: 2}
    assert %{..., a: 1} = m

    match_fails(
      assert(%{a: 1} = m),
      """
      left:  %{}
      right: %{b: 2}
      """
    )
  end
end

defmodule ExMatchTest.UseOptsValue do
  use ExUnit.Case

  use ExMatch,
    opts: %{
      ExMatchTest.Dummy => %{b: {1, _, _, ExMatchTest.Dummy.id(3 + 1)}}
    }

  alias ExMatchTest.Dummy

  import ExMatchTest.Dummy, only: [id: 1]
  import ExMatchTest.TestCase, only: [match_fails: 2]

  test "exmatch _ == _ passes" do
    exmatch %ExMatchTest.Dummy{..., a: id(1)} == %Dummy{a: 1, b: {1, 2, 3, 4}, c: 10}
  end

  test "exmatch _ == _ fails" do
    match_fails(
      exmatch(%ExMatchTest.Dummy{a: 1 + 1} == %Dummy{a: 1, b: {0, 1, 2, 3, 4}, c: 10}),
      """
      left:  %ExMatchTest.Dummy{b: {1, ..2.., ExMatchTest.Dummy.id(3 + 1) = 4}, a: 1 + 1 = 2}
      right: %ExMatchTest.Dummy{a: 1, b: {0, ..2.., 3, 4}, c: 10}
      """
    )
  end

  test "exmatch _ = _" do
    exmatch [1, id(1 + 1), 3] = [1, 2, 3]

    match_fails(
      exmatch([1, id(1 + 1), 3] = [1, 2, 4]),
      """
      left:  [..2.., 3]
      right: [..2.., 4]
      """
    )
  end
end
