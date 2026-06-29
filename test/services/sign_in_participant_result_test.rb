# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignInParticipantResultTest < ActiveSupport::TestCase
  setup do
    @item = Struct.new(:blocking?, :cleared?, keyword_init: true)
  end

  test "initializes attributes" do
    result = SignInParticipantResult.new(
      participant: :client,
      stack: [1, 2],
      next_status: :complete,
      message: "Done",
    )

    assert_equal :client, result.participant
    assert_equal [1, 2], result.stack
    assert_equal :complete, result.next_status
    assert_equal "Done", result.message
  end

  test "empty? delegates to stack" do
    empty_result = SignInParticipantResult.new(participant: :client, stack: [], next_status: :complete)
    non_empty_result = SignInParticipantResult.new(participant: :client, stack: [1], next_status: :complete)

    assert_predicate empty_result, :empty?
    assert_not_predicate non_empty_result, :empty?
  end

  test "blocking? returns true when any item blocks and is not cleared" do
    stack = [@item.new(blocking?: true, cleared?: false)]
    result = SignInParticipantResult.new(participant: :client, stack: stack, next_status: :complete)

    assert_predicate result, :blocking?
  end

  test "blocking? returns false when blocking item is cleared" do
    stack = [@item.new(blocking?: true, cleared?: true)]
    result = SignInParticipantResult.new(participant: :client, stack: stack, next_status: :complete)

    assert_not_predicate result, :blocking?
  end

  test "blocking? returns false when no item blocks" do
    stack = [@item.new(blocking?: false, cleared?: false)]
    result = SignInParticipantResult.new(participant: :client, stack: stack, next_status: :complete)

    assert_not_predicate result, :blocking?
  end

  test "cleared? returns false when blocking" do
    stack = [@item.new(blocking?: true, cleared?: false)]
    result = SignInParticipantResult.new(participant: :client, stack: stack, next_status: :complete)

    assert_not_predicate result, :cleared?
  end

  test "cleared? returns true when not blocking" do
    stack = [@item.new(blocking?: false, cleared?: false)]
    result = SignInParticipantResult.new(participant: :client, stack: stack, next_status: :complete)

    assert_predicate result, :cleared?
  end
end
