# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpCycleLocatorTest < ActiveSupport::TestCase
  fixtures_none!

  test "raises for unsupported surface" do
    assert_raises(ArgumentError, match: "unsupported sign-up cycle surface") do
      SignUpCycleLocator.new({}, surface: :invalid)
    end
  end

  test "raises for wrong cycle class in issue!" do
    session = {}
    locator = SignUpCycleLocator.new(session, surface: :app)
    wrong_cycle = VisitorSignUpFlow.new

    assert_raises(ArgumentError, match: "unsupported sign-up cycle") do
      locator.issue!(wrong_cycle)
    end
  end

  test "returns nil when payload is missing required keys" do
    session = { app_sign_up_flow_locator: { "public_id" => "missing-nonce" } }
    locator = SignUpCycleLocator.new(session, surface: :app)

    assert_nil locator.current
  end

  test "rescues KeyError when nonce is missing from session" do
    cycle = ClientSignUpFlow.create!(
      principal_id: 123,
      status_id: ClientSignUpFlowStatus::STARTED,
      step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("a-nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: "email",
    )

    session = { app_sign_up_flow_locator: { "public_id" => cycle.public_id } }
    locator = SignUpCycleLocator.new(session, surface: :app)

    assert_nil locator.current
  end
end
