defmodule ExMatchTest.DateTime do
  use ExMatchTest.TestCase

  require ExMatch

  @datetime Timex.parse!("2022-02-19 14:55:08.387165+09:45", "{ISO:Extended}")

  test "match" do
    # Timex keeps offsets in the DateTime unlike DateTime.parse
    ExMatch.match("2022-02-19 14:55:08.387165+09:45", @datetime, [{DateTime, [:match_string]}])
    ExMatch.match("2022-02-19 05:10:08.387165Z", @datetime, [{DateTime, [:match_string]}])
    ExMatch.match(~U[2022-02-19 05:10:08.387165Z], @datetime)
  end

  test "diff without :match_string option" do
    match_fails(
      ExMatch.match("2022-02-19 14:55:08.387165+09:45", @datetime),
      """
      left:  "2022-02-19 14:55:08.387165+09:45"
      right: #DateTime<2022-02-19 14:55:08.387165+09:45 +09:45 Etc/UTC+9:45>
      """
    )
  end

  test "diff with different timezone without :match_string option" do
    match_fails(
      ExMatch.match("2022-02-19 05:10:08.387165Z", @datetime),
      """
      left:  "2022-02-19 05:10:08.387165Z"
      right: #DateTime<2022-02-19 14:55:08.387165+09:45 +09:45 Etc/UTC+9:45>
      """
    )
  end

  test "expression diff displays inspected value" do
    datetime = @datetime

    match_fails(
      ExMatch.match(^datetime, nil),
      """
      left:  ^datetime = #DateTime<2022-02-19 14:55:08.387165+09:45 +09:45 Etc/UTC+9:45>
      right: nil
      """
    )
  end
end
