defmodule ExMatchTest.Tuple do
  use ExMatchTest.TestCase
  require ExMatch

  test "match" do
    ExMatch.match({}, {})
    ExMatch.match({1}, {1})
    ExMatch.match({1, 2}, {1, 2})
    ExMatch.match({_, 2}, {1, 2})
    ExMatch.match({1, 2, 3}, {1, 2, 3})
    ExMatch.match({1, 2, 3, 4}, {1, 2, 3, 4})
    ExMatch.match({a, 2, 3, b}, {1, 2, 3, 4})
    assert {a, b} == {1, 4}
  end

  test "diff in tail" do
    match_fails(
      ExMatch.match({1, 2, 4}, {1, 2, 3}),
      """
      left:  {..2.., 4}
      right: {..2.., 3}
      """
    )
  end

  test "nothing matches" do
    match_fails(
      ExMatch.match({1, 2, 4}, {2, 4}),
      """
      left:  {1, 2, 4}
      right: {2, 4}
      """
    )
  end

  test "diff in the middle" do
    match_fails(
      ExMatch.match({1, {2, 3}, 4}, {1, 2, 4}),
      """
      left:  {.., {2, 3}, ..}
      right: {.., 2, ..}
      """
    )
  end

  test "diff with ignored value" do
    match_fails(
      ExMatch.match({_, 2}, {1, 2, 3, 4}),
      """
      left:  {..2..}
      right: {..2.., 3, 4}
      """
    )
  end

  test "one matches fully" do
    match_fails(
      ExMatch.match({1, 2}, {1, 2, 3, 4}),
      """
      left:  {..2..}
      right: {..2.., 3, 4}
      """
    )
  end

  test "expr containing a tuple of 3 elements" do
    l = {1, 2, 4}

    match_fails(
      ExMatch.match(^l, {2, 4}),
      """
      left:  ^l = {1, 2, 4}
      right: {2, 4}
      """
    )
  end
end
