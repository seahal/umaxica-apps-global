# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Webauthn::ConfigTest < ActiveSupport::TestCase
  class TestController < ApplicationController
    include Sign::Webauthn

    def index
      render plain: "ok"
    end
  end

  setup do
    @controller = TestController.new
    @controller.request = ActionDispatch::TestRequest.create
    @controller.response = ActionDispatch::TestResponse.new

    # Mock session for unit testing the concern methods directly
    session_hash = {}
    @controller.define_singleton_method(:session) { session_hash }
  end

  # Case B-1: webauthn_rp_id should return request.host
  test "webauthn_rp_id returns request host" do
    @controller.request.host = "id.app.localhost"

    assert_equal "id.app.localhost", @controller.webauthn_rp_id
  end

  # Case B-2: webauthn_origin should return request.base_url
  test "webauthn_origin returns request base_url" do
    @controller.request.host = "id.app.localhost"
    @controller.request.set_header("rack.url_scheme", "http")

    assert_equal "http://id.app.localhost", @controller.webauthn_origin
  end

  # Case B-3: validate_webauthn_origin! rejects origins that are not trusted
  test "validate_webauthn_origin! raises error for untrusted origin" do
    @controller.request.host = "evil.example.com"

    assert_raises(Sign::Webauthn::OriginValidationError) do
      @controller.validate_webauthn_origin!
    end
  end

  # Case B-4 & B-5: Challenge Management
  test "challenge management flow" do
    @controller.request.host = "id.app.localhost" # valid host

    # Create challenge
    challenge_id = @controller.send(:store_challenge!, challenge: "test-challenge", purpose: :registration)

    assert_not_nil challenge_id

    # Verify it is in session
    challenges = @controller.session[Sign::Webauthn::CHALLENGE_SESSION_KEY]

    assert_not_nil challenges[challenge_id]
    assert_equal "test-challenge", challenges[challenge_id]["challenge"]

    # Fetch and delete (consuming the challenge)
    retrieved_challenge = @controller.send(:fetch_and_delete_challenge!, challenge_id, purpose: :registration)

    assert_equal "test-challenge", retrieved_challenge

    # Verify it is gone
    challenges = @controller.session[Sign::Webauthn::CHALLENGE_SESSION_KEY]

    assert_nil challenges[challenge_id]
  end

  test "fetch_and_delete_challenge! raises error on wrong purpose" do
    @controller.request.host = "id.app.localhost"
    challenge_id = @controller.send(:store_challenge!, challenge: "test", purpose: :registration)

    assert_raises(Sign::Webauthn::ChallengePurposeMismatchError) do
      @controller.send(:fetch_and_delete_challenge!, challenge_id, purpose: :authentication)
    end
  end

  test "fetch_and_delete_challenge! raises error when expired" do
    @controller.request.host = "id.app.localhost"
    challenge_id = @controller.send(:store_challenge!, challenge: "test", purpose: :registration)

    # Manually expire it
    challenges = @controller.session[Sign::Webauthn::CHALLENGE_SESSION_KEY]
    challenges[challenge_id]["expires_at"] = 1.minute.ago.to_i

    assert_raises(Sign::Webauthn::ChallengeExpiredError) do
      @controller.send(:fetch_and_delete_challenge!, challenge_id, purpose: :registration)
    end
  end
end
