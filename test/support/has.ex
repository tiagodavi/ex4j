defmodule Test.HasComment do
  use Ex4j.Schema

  relationship "HAS_COMMENT" do
    from(Test.User)
    to(Test.Comment)
    field(:created_at, :utc_datetime)
  end
end
