# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignInSequencePolicyTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @user = clients(:one)
    @sequence = SignInSequence.new(
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
    expired = SignInSequence.new(@sequence.payload.merge("expires_at" => 1.minute.ago.iso8601))
    policy = SignIn::SequencePolicy.new(expired, user: @user)

    assert_not_predicate policy, :show_checkpoint?
  end

  test "missing sequence is blank and has no valid window" do
    sequence = SignInSequence.missing

    assert_predicate sequence, :blank?
    assert_nil sequence.id
    assert_not sequence.valid_for?(surface: :app, actor: @user, participant: :checkpoint)
  end

  test "invalid timestamps are treated as absent" do
    sequence = SignInSequence.new(
      @sequence.payload.merge("created_at" => "not-a-time", "updated_at" => "not-a-time", "expires_at" => "not-a-time"),
    )

    assert_nil sequence.created_at
    assert_nil sequence.updated_at
    assert_nil sequence.expires_at
    assert_predicate sequence, :expired?
  end
end
