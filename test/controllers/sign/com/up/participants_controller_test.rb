# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Up::ParticipantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    cookies["csrf_token"] = csrf_token_value
  end

  test "guardrail rejects direct access without a ticket" do
    get sign_com_up_guardrail_url(ri: "jp"), headers: default_headers

    assert_response :not_found
    assert_equal "Not found", response.body
  end

  test "guardrail rejects ticket id without session binding" do
    ticket = create_ticket(status_id: VisitorSignUpCycleStatus::CONTACT_VERIFIED, step: "contact_verified")

    get sign_com_up_guardrail_url(ri: "jp", sid: ticket.public_id), headers: default_headers

    assert_response :not_found
    assert_equal "Not found", response.body
  end

  test "checkpoint show rejects ticket id without session binding" do
    ticket = create_ticket(status_id: VisitorSignUpCycleStatus::GUARDRAIL_PENDING, step: "guardrail")

    get sign_com_up_checkpoint_url(ri: "jp", sid: ticket.public_id), headers: default_headers

    assert_response :not_found
    assert_equal "Not found", response.body
  end

  test "checkpoint update rejects direct access without a ticket" do
    patch sign_com_up_checkpoint_url(ri: "jp"),
          params: { requirement: "birthdate" },
          headers: default_headers

    assert_response :not_found
    assert_equal "Not found", response.body
  end

  private

  def create_ticket(attrs = {})
    VisitorSignUpCycle.create!(
      {
        principal_id: nil,
        status_id: VisitorSignUpCycleStatus::STARTED,
        step: "start",
        nonce_digest: VisitorSignUpCycle.digest_nonce("nonce"),
        issued_at: Time.current,
        expires_at: 15.minutes.from_now,
        entry_method: "email",
      }.merge(attrs),
    )
  end

  def default_headers
    { "Host" => host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end
end
