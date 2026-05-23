# typed: false
# frozen_string_literal: true

require "test_helper"

class SignIn::SequenceCarrierTest < ActiveSupport::TestCase
  fixtures_none!

  ClientStub = Struct.new(:id)

  test "stores sequence state in a surface-local session key" do
    session = {}
    actor = ClientStub.new(42)

    sequence = SignIn::SequenceCarrier.new(session, surface: :app).start!(
      surface: :app,
      actor: actor,
      method: :email_otp,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      rt: "/configuration",
    )

    assert_equal sequence.id, session.fetch(:app_sign_in_sequence).fetch("id")
    assert_nil session[:com_sign_in_sequence]
    assert_nil session[SignIn::SequenceCarrier::KEY]
  end

  test "does not expose another surface sequence as current" do
    session = {}
    actor = ClientStub.new(42)

    SignIn::SequenceCarrier.new(session, surface: :app).start!(
      surface: :app,
      actor: actor,
      method: :email_otp,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      rt: nil,
    )

    assert_predicate SignIn::SequenceCarrier.new(session, surface: :app).current, :present?
    assert_not SignIn::SequenceCarrier.new(session, surface: :com).current.present?
  end

  test "terminal sequence is not valid for a participant" do
    session = {}
    actor = ClientStub.new(42)
    carrier = SignIn::SequenceCarrier.new(session, surface: :app)

    carrier.start!(
      surface: :app,
      actor: actor,
      method: :email_otp,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      rt: nil,
    )
    sequence = carrier.fail!

    assert_predicate sequence, :terminal?
    assert_not sequence.valid_for?(surface: :app, actor: actor, participant: :checkpoint)
  end

  test "legacy key is migrated only for matching surface" do
    session = {
      SignIn::SequenceCarrier::KEY => {
        "id" => SecureRandom.uuid,
        "surface" => "app",
        "actor_type" => ClientStub.name,
        "actor_id" => 42,
        "state" => "CHECKPOINT_PENDING",
        "participant" => "checkpoint",
        "expires_at" => 10.minutes.from_now.iso8601,
      },
    }

    assert_not SignIn::SequenceCarrier.new(session, surface: :com).current.present?
    assert_predicate SignIn::SequenceCarrier.new(session, surface: :app).current, :present?
    assert_nil session[SignIn::SequenceCarrier::KEY]
  end

  test "unsupported surface does not fall back to app" do
    session = {}
    actor = ClientStub.new(42)

    assert_raises(ArgumentError) do
      SignIn::SequenceCarrier.new(session, surface: :net).start!(
        surface: :net,
        actor: actor,
        method: :email_otp,
        state: "CHECKPOINT_PENDING",
        participant: :checkpoint,
        rt: nil,
      )
    end

    assert_not SignIn::SequenceCarrier.new(session, surface: :net).current.present?
    assert_nil session[:app_sign_in_sequence]
  end

  test "unsupported state and participant are rejected" do
    session = {}
    actor = ClientStub.new(42)
    carrier = SignIn::SequenceCarrier.new(session, surface: :app)

    assert_raises(ArgumentError) do
      carrier.start!(
        surface: :app,
        actor: actor,
        method: :email_otp,
        state: "BOGUS",
        participant: :checkpoint,
        rt: nil,
      )
    end

    assert_raises(ArgumentError) do
      carrier.start!(
        surface: :app,
        actor: actor,
        method: :email_otp,
        state: "CHECKPOINT_PENDING",
        participant: :unknown,
        rt: nil,
      )
    end
  end
end
