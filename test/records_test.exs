defmodule ExMatchTest.Records do
  use ExMatchTest.TestCase

  require ExMatch
  require Record

  Record.defrecordp(:some_record, ExMatchTest.SomeRecord, [:a, :b, :c])

  test "simple" do
    r = some_record(a: 1)
    ExMatch.match(some_record(a: 1) == r)
    ExMatch.match(some_record(a: a) = some_record(r, a: 2))
    assert 2 == a
  end

  test "diff in a field" do
    match_fails(
      ExMatch.match(some_record(a: 0) == some_record(a: 1)),
      """
      left:  some_record(a: 0) =~ {.., 0, ..2..}
      right: {.., 1, ..2..}
      """
    )
  end

  test "diff in a field with explicit nil" do
    match_fails(
      ExMatch.match(some_record(a: 0, b: nil) == some_record(a: 1)),
      """
      left:  some_record(a: 0, b: nil) =~ {.., 0, ..2..}
      right: {.., 1, ..2..}
      """
    )
  end
end
