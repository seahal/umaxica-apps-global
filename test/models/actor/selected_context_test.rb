# typed: false
# frozen_string_literal: true

require "test_helper"

class Actor::SelectedContextTest < ActiveSupport::TestCase
  fixtures_none!

  test "NULL context is not selected" do
    assert_not Actor::SelectedContext::NULL.selected?
  end

  test "equality returns false for non-selected-context objects" do
    context = Actor::SelectedContext.new(account_public_id: "account")

    assert_not_equal context, "not a context"
  end

  test "hash is consistent for equal contexts" do
    context_a = Actor::SelectedContext.new(
      account_public_id: "account",
      collective_public_id: "collective",
      collective_unit_public_id: "unit",
    )
    context_b = Actor::SelectedContext.new(
      account_public_id: "account",
      collective_public_id: "collective",
      collective_unit_public_id: "unit",
    )

    assert_equal context_a, context_b
    assert_equal context_a.hash, context_b.hash
  end
end
