# frozen_string_literal: true

require "test_helper"

# The CMS update action branches on `ok?` alone and then renders `errors` straight into the edit
# view. A success carrying errors, or a failure carrying a revision, would put the caller on the
# wrong branch with data that looks valid, so the two shapes are pinned here.
class PublishingReviseEntryResultTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a success carries the revision and no errors" do
    revision = Object.new
    result = PublishingReviseEntryResult.success(revision)

    assert_predicate result, :ok?
    assert_same revision, result.revision
    assert_empty result.errors
  end

  test "a failure carries the errors and no revision" do
    result = PublishingReviseEntryResult.failure(lock_version: "is stale")

    assert_not_predicate result, :ok?
    assert_nil result.revision
    assert_equal({ lock_version: "is stale" }, result.errors)
  end

  # `render_edit_failure` passes `result.errors` to a view that indexes it by attribute name, so a
  # failure with several attributes has to keep all of them rather than collapse to the first.
  test "a failure keeps every attribute it was given" do
    result = PublishingReviseEntryResult.failure(title: "can't be blank", body: "must be a JSON object")

    assert_equal({ title: "can't be blank", body: "must be a JSON object" }, result.errors)
  end
end
