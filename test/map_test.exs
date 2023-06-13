defmodule ExMatchTest.Map do
  use ExMatchTest.TestCase

  require ExMatch

  @map %{a: 1, b: 2, c: 3, d: %{e: 11, f: 12}}

  test "match" do
    eleven = 11
    two = 2

    ExMatch.match(%{a: id(1), b: b, c: c, d: %{e: ^eleven, f: eleven + 1}}, @map)
    assert {2, 3} == {b, c}

    ExMatch.match(%{..., b: ExMatchTest.Dummy.id(two), c: b, d: %{..., f: a}}, @map)
    assert a == 12
    assert b == 3

    ref = make_ref()
    ExMatch.match(%{"key" => 1, {1, 2} => 2, ref => 3}, %{"key" => 1, {1, 2} => 2, ref => 3})
  end

  test "diff skips a matching field" do
    two = 2

    match_fails(
      ExMatch.match(%{b: ^two}, @map),
      """
      left:  %{}
      right: %{a: 1, c: 3, d: %{e: 11, f: 12}}
      """
    )
  end

  test "diff whole map" do
    match_fails(
      ExMatch.match(%{a: 1, b: 2, c: 3, d: %{e: 11, f: 12}}, 1),
      """
      left:  %{a: 1, b: 2, c: 3, d: %{e: 11, f: 12}}
      right: 1
      """
    )
  end

  test "diff skipped fields" do
    match_fails(
      ExMatch.match(%{..., a: 1, c: 3, d: %{e: 11, f: 12}}, 1),
      """
      left:  %{..., a: 1, c: 3, d: %{e: 11, f: 12}}
      right: 1
      """
    )
  end

  test "diff whole map behind a variable" do
    map = Map.put(@map, "key", 10)

    match_fails(
      ExMatch.match(^map, 1),
      """
      left:  ^map = %{a: 1, b: 2, c: 3, d: %{e: 11, f: 12}}
      right: 1
      """
    )
  end

  test "diff skips multiple matching fields" do
    match_fails(
      ExMatch.match(%{a: 1, b: 2, c: 2}, @map),
      """
      left:  %{c: 2}
      right: %{c: 3, d: %{e: 11, f: 12}}
      """
    )
  end

  test "diff skips multiple matching fields behind a variable" do
    map = @map

    match_fails(
      ExMatch.match(^map, %{c: 3, a: 1}),
      """
      left:  ^map =~ %{b: 2, d: %{e: 11, f: 12}}
      right: %{}
      """
    )
  end

  test "diff with partial match" do
    match_fails(
      ExMatch.match(%{..., a: 1, c: 2}, @map),
      """
      left:  %{c: 2}
      right: %{c: 3}
      """
    )
  end

  test "diff with expression in a field" do
    eleven = 11
    two = 2

    match_fails(
      ExMatch.match(
        %{a: 1, c: _c, x: _, y: 6, d: ExMatchTest.Dummy.id(eleven + two)},
        @map
      ),
      """
      left:  %{d: ExMatchTest.Dummy.id(eleven + two) = 13, x: _, y: 6}
      right: %{d: %{e: 11, f: 12}, b: 2}
      """
    )
  end

  test "diff shows non-atom keys" do
    ref = make_ref()

    match_fails(
    ExMatch.match(%{"key" => 1, {1, 2} => 2, ref => 3}, %{"key" => 8, {1, 2} => 2, ref => 4}),
    """
    left:  %{#{inspect(ref)} => 3, "key" => 1}
    right: %{#{inspect(ref)} => 4, "key" => 8}
    """
    )
  end

  test "diff shows non-atom keys in partial pattern" do
    ref = make_ref()

    match_fails(
    ExMatch.match(%{..., "key" => 1, ref => 3}, %{"key" => 8, {1, 2} => 2, ref => 4}),
    """
    left:  %{#{inspect(ref)} => 3, "key" => 1}
    right: %{#{inspect(ref)} => 4, "key" => 8}
    """
    )
  end
end
