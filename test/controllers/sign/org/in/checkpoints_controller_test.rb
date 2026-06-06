# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Org::In::CheckpointsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    OperatorSignInFlowStatus.ensure_defaults!
  end

  test "show without login is rejected" do
    get sign_org_in_check_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "show without sign in sequence is rejected" do
    get sign_org_in_check_url(ri: "jp"),
        headers: as_staff_headers(@staff, host: @host)

    assert_response :bad_request
  end

  test "show with bulletin returns success" do
    start_checkpoint_sequence

    get sign_org_in_check_url(ri: "jp"),
        headers: checkpoint_headers.merge(
          "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "new"),
        )

    assert_response :bad_request
  end

  test "update refreshes state and issued_at then redirects to show" do
    start_checkpoint_sequence
    previous_issued_at = 10.minutes.ago.to_i

    patch sign_org_in_check_url(ri: "jp"),
          headers: checkpoint_headers.merge(
            "X-TEST-BULLETIN" => bulletin_json(issued_at: previous_issued_at, state: "new"),
          )

    assert_response :bad_request
  end

  test "destroy consumes bulletin and continues to dashboard with pt" do
    start_checkpoint_sequence
    pt = Base64.urlsafe_encode64("/settings")

    delete sign_org_in_check_url(ri: "jp", pt: pt),
           headers: checkpoint_headers.merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_response :bad_request
  end

  test "destroy without pt redirects to default" do
    start_checkpoint_sequence

    delete sign_org_in_check_url(ri: "jp"),
           headers: checkpoint_headers.merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_response :bad_request
  end

  test "show and update return timeout when expired" do
    start_checkpoint_sequence
    expired_at = 2.hours.ago.to_i - 1

    get sign_org_in_check_url(ri: "jp"),
        headers: checkpoint_headers.merge(
          "X-TEST-BULLETIN" => bulletin_json(issued_at: expired_at, state: "new"),
        )

    assert_response :bad_request

    patch sign_org_in_check_url(ri: "jp"),
          headers: checkpoint_headers

    assert_response :bad_request
  end

  test "destroy still redirects when expired" do
    start_checkpoint_sequence
    pt = Base64.urlsafe_encode64("/settings")

    delete sign_org_in_check_url(ri: "jp", pt: pt),
           headers: checkpoint_headers.merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: 2.hours.ago.to_i - 1, state: "updated"),
           )

    assert_response :bad_request
  end

  private

  def start_checkpoint_sequence
    @checkpoint_headers = as_staff_headers(@staff, host: @host)
    get(sign_org_dashboard_url(ri: "jp"), headers: checkpoint_headers)

    SignInSequenceCarrier.new(session, surface: :org).start!(
      surface: :org,
      actor: @staff,
      method: :passkey,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      pt: nil,
    )
    cycle = OperatorSignInFlow.new(
      principal_id: @staff.id,
      status_id: OperatorSignInFlow.status_id_for("CHECKPOINT_PENDING"),
      state: "CHECKPOINT_PENDING",
      step: "checkpoint",
      nonce_digest: OperatorSignInFlow.digest_nonce("pending-test-nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
    )
    cycle.save!(validate: false)
    SignInCycleLocator.new(session, surface: :org, actor: @staff).issue!(cycle)
  end

  def checkpoint_headers
    @checkpoint_headers ||= as_staff_headers(@staff, host: @host)
  end

  def bulletin_json(issued_at:, state:)
    { "issued_at" => issued_at, "kind" => "mock", "state" => state }.to_json
  end
end
