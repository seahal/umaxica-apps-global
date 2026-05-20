# typed: false
# frozen_string_literal: true

require "test_helper"

class SignInSequencePolicyTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @user = clients(:one)
    @sequence = SignIn::Sequence.new(
      "id" => SecureRandom.uuid,
      "surface" => "app",
      "actor_type" => "Client",
      "actor_id" => @user.id,
      "method" => "email_otp",
      "state" => "CHECKPOINT_PENDING",
      "participant" => "checkpoint",
      "expires_at" => 10.minutes.from_now.iso8601,
    )
  end

  test "allows checkpoint participant for matching authenticated actor" do
    policy = SignIn::SequencePolicy.new(@sequence, user: @user)

    assert_predicate policy, :show_checkpoint?
    assert_predicate policy, :update_checkpoint?
    assert_predicate policy, :destroy_checkpoint?
  end

  test "rejects checkpoint participant for wrong actor" do
    other_user = clients(:two)
    policy = SignIn::SequencePolicy.new(@sequence, user: other_user)

    assert_not_predicate policy, :show_checkpoint?
  end

  test "rejects expired sequence" do
    expired = SignIn::Sequence.new(@sequence.payload.merge("expires_at" => 1.minute.ago.iso8601))
    policy = SignIn::SequencePolicy.new(expired, user: @user)

    assert_not_predicate policy, :show_checkpoint?
  end
end
