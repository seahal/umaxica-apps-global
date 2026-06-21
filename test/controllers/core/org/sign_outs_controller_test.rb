# typed: false
# frozen_string_literal: true

require "test_helper"

class Core::Org::SignOutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("CORE_STAFF_URL", "www-jp.umaxica.org")
    host! @host
  end

  test "get sign out renders confirmation without mutation" do
    staff = Operator.create!(
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    token = OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    satisfy_staff_verification(token)

    get edit_core_org_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :success
    assert_select "form[action*=?][method=?]", core_org_sign_out_path, "post"
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out redirects to acme oidc logout with completion state" do
    staff = Operator.create!(
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    token = OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    satisfy_staff_verification(token)

    post core_org_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :temporary_redirect
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("ACME_STAFF_URL", "www.org.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["id_token_hint"], :present?
    assert_equal complete_core_org_sign_out_url(ri: "jp"), query["post_logout_redirect_uri"]
    assert_predicate query["state"], :present?
  end

  test "complete sign out consumes the state and renders completion" do
    staff = Operator.create!(
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    token = OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    satisfy_staff_verification(token)

    post core_org_sign_out_url(ri: "jp"), headers: {
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    state = Rack::Utils.parse_nested_query(URI.parse(response.location).query.to_s)["state"]
    get complete_core_org_sign_out_url(ri: "jp", state: state)

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end
end
