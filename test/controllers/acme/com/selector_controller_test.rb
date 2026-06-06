# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::SelectorControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
  end

  test "authenticated visitor without selected actor context can access selector" do
    get acme_com_selector_url(host: @host), headers: as_visitor_headers(
      @visitor,
      host: @host,
      session_public_id: @token.public_id,
    ), as: :json

    assert_response :success
    assert_equal "selected", JSON.parse(response.body).fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
    assert_nil @token.selected_avatar_public_id if @token.respond_to?(:selected_avatar_public_id)
  end
end
