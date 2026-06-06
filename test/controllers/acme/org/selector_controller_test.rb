# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Org::SelectorControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
  end

  test "authenticated operator without selected actor context can access selector" do
    get acme_org_selector_url(host: @host), headers: as_staff_headers(
      @operator,
      host: @host,
      session_public_id: @token.public_id,
    ), as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
    assert_nil @token.selected_avatar_public_id if @token.respond_to?(:selected_avatar_public_id)
  end
end
