# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::SwitcherControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
  end

  test "unauthenticated visitor cannot access switcher" do
    get acme_com_switcher_url(host: @host), headers: host_headers(@host), as: :json

    assert_response :unauthorized
  end

  test "authenticated visitor can access switcher show" do
    select_token!
    get acme_com_switcher_url(host: @host), headers: as_visitor_headers(
      @visitor,
      host: @host,
      session_public_id: @token.public_id,
    ), as: :json

    assert_response :success
    assert_equal "stub", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "authenticated visitor can access switcher update" do
    select_token!
    patch acme_com_switcher_url(host: @host), headers: as_visitor_headers(
      @visitor,
      host: @host,
      session_public_id: @token.public_id,
    ), as: :json

    assert_response :success
    assert_equal "stub", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  private

  def select_token!
    AcmeSelectorBootstrapAuthority.call(surface: :com, principal: @visitor)
    AcmeSelectorAuthority.prepare(surface: :com, principal: @visitor, session: @token)
  end
end
