# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Org::SwitcherControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
  end

  test "unauthenticated operator cannot access switcher" do
    get acme_org_switcher_url(host: @host), headers: host_headers(@host), as: :json

    assert_response :unauthorized
  end

  test "authenticated operator can access switcher show" do
    select_token!
    get acme_org_switcher_url(host: @host), headers: as_staff_headers(
      @operator,
      host: @host,
      session_public_id: @token.public_id,
    ), as: :json

    assert_response :success
    assert_equal "stub", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "authenticated operator can access switcher update" do
    select_token!
    patch acme_org_switcher_url(host: @host), headers: as_staff_headers(
      @operator,
      host: @host,
      session_public_id: @token.public_id,
    ), as: :json

    assert_response :success
    assert_equal "stub", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  private

  def select_token!
    AcmeSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    AcmeSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
  end
end
