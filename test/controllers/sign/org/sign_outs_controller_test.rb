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

  test "sign_out_get_redirect_is_not_session_mutation" do
    token = OperatorToken.create!(staff: @staff)

    get sign_org_sign_out_url(ri: "jp"), headers: session_headers(token)

    assert_redirect_to_acme_sign_out
    assert_predicate token.reload, :currently_usable?
  end

  test "sign_out_post_redirect_uses_acme_authority" do
    token = OperatorToken.create!(staff: @staff)

    post sign_org_sign_out_url(ri: "jp"), params: { confirm: "1" }, headers: session_headers(token)

    assert_redirect_to_acme_sign_out
    assert_predicate token.reload, :currently_usable?
  end

  test "sign_out_destroy_redirect_is_not_session_mutation" do
    token = OperatorToken.create!(staff: @staff)

    delete sign_org_sign_out_url(ri: "jp"), headers: session_headers(token)

    assert_redirect_to_acme_sign_out
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

  def assert_redirect_to_acme_sign_out
    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal @acme_host, location.host
    assert_equal "/sign/out", location.path
    assert_equal "ri=jp", location.query
  end
end
