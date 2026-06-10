# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::SignOutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
  end

  test "sign out confirmation does not mutate the session" do
    token = OperatorToken.create!(staff: @staff)

    get sign_org_sign_out_confirmation_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_predicate token.reload, :currently_usable?
  end

  test "sign out attempt logs out and shows completion" do
    token = OperatorToken.create!(staff: @staff)

    post sign_org_sign_out_attempt_url(ri: "jp"), params: { confirm: "1" }, headers: session_headers(token)

    assert_redirected_to sign_org_sign_out_completion_url(ri: "jp")
  end

  test "sign out attempt without confirmation redirects back without mutation" do
    token = OperatorToken.create!(staff: @staff)

    post sign_org_sign_out_attempt_url(ri: "jp"), headers: session_headers(token)

    assert_redirected_to sign_org_sign_out_confirmation_url(ri: "jp")
    assert_predicate token.reload, :currently_usable?
  end

  private

  def session_headers(token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
