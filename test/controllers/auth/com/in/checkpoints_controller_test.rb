# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Auth::Com::Sign::In::CheckpointsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
    ApplicationRecord.clear_fixed_id_seed_cache!
    VisitorSignInFlowStatus.ensure_defaults!
    @visitor = create_verified_visitor_with_email(email_address: "checkpoint-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+10000000992",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
  end

  test "show without login is rejected" do
    get auth_com_sign_in_check_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "show without sign in sequence is rejected" do
    get auth_com_sign_in_check_url(ri: "jp"),
        headers: as_visitor_headers(@visitor, host: @host)

    assert_response :bad_request
  end

  test "show with checkpoint notice state without sequence authorization is rejected" do
    start_checkpoint_sequence

    get auth_com_sign_in_check_url(ri: "jp"),
        headers: checkpoint_headers.merge(
          "X-TEST-BULLETIN" => checkpoint_json(issued_at: Time.current.to_i, state: "new"),
        )

    assert_response :bad_request
  end

  test "update with checkpoint notice state without sequence authorization is rejected" do
    start_checkpoint_sequence
    previous_issued_at = 10.minutes.ago.to_i

    patch auth_com_sign_in_check_url(ri: "jp"),
          headers: checkpoint_headers.merge(
            "X-TEST-BULLETIN" => checkpoint_json(issued_at: previous_issued_at, state: "new"),
          )

    assert_response :bad_request
  end

  test "destroy is rejected by routing" do
    start_checkpoint_sequence
    pt = Base64.urlsafe_encode64("/settings?ri=jp")

    delete auth_com_sign_in_check_url(ri: "jp", pt: pt),
           headers: checkpoint_headers.merge(
             "X-TEST-BULLETIN" => checkpoint_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_response :not_found
  end

  test "destroy without pt is rejected by routing" do
    start_checkpoint_sequence

    delete auth_com_sign_in_check_url(ri: "jp"),
           headers: checkpoint_headers.merge(
             "X-TEST-BULLETIN" => checkpoint_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_response :not_found
  end

  test "expired checkpoint returns timeout" do
    start_checkpoint_sequence

    get auth_com_sign_in_check_url(ri: "jp"),
        headers: checkpoint_headers.merge(
          "X-TEST-BULLETIN" => checkpoint_json(issued_at: 2.hours.ago.to_i - 1, state: "new"),
        )

    assert_response :bad_request
  end

  private

  def start_checkpoint_sequence
    @checkpoint_headers = as_visitor_headers(@visitor, host: @host)
    get(auth_com_dashboard_url(ri: "jp"), headers: checkpoint_headers)

    SignInSequenceCarrier.new(session, surface: :com).start!(
      surface: :com,
      actor: @visitor,
      method: :email_otp,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      pt: nil,
    )
    cycle = VisitorSignInFlow.new(
      principal_id: @visitor.id,
      status_id: VisitorSignInFlow.status_id_for("CHECKPOINT_PENDING"),
      state: "CHECKPOINT_PENDING",
      step: "checkpoint",
      nonce_digest: VisitorSignInFlow.digest_nonce("pending-test-nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
    )
    cycle.save!(validate: false)
    SignInCycleLocator.new(session, surface: :com, actor: @visitor).issue!(cycle)
  end

  def checkpoint_headers
    @checkpoint_headers ||= as_visitor_headers(@visitor, host: @host)
  end

  def checkpoint_json(issued_at:, state:)
    { "issued_at" => issued_at, "kind" => "notice", "state" => state }.to_json
  end
end
