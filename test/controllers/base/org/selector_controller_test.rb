# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"
require "helpers/auth_helpers"

class Base::Org::SelectorControllerTest < ActionDispatch::IntegrationTest
  include AuthHelpers

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    set_access_cookie(
      jwt_access_token_for(
        @operator, host: @host, session_public_id: @token.public_id,
                   resource_type: "operator",
      ),
    )
    bootstrap_and_select!(@operator, @token)
  end

  test "authenticated operator without selected actor context can access selector" do
    get base_org_selector_url(host: @host), headers: as_staff_headers(
      @operator,
      host: @host,
      session_public_id: @token.public_id,
    ), as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
    assert_nil @token.selected_avatar_public_id if @token.respond_to?(:selected_avatar_public_id)
  end

  test "selector update renders invalid selection error as json" do
    BaseSelectorAuthority.stub(:select, ->(*) { raise BaseSelectorAuthority::InvalidSelection, "bad" }) do
      patch base_org_selector_url(host: @host),
            params: { account_public_id: "invalid" },
            headers: as_staff_headers(@operator, host: @host, session_public_id: @token.public_id),
            as: :json
    end

    assert_response :unprocessable_content
    assert_equal "invalid_selection", response.parsed_body.fetch("status")
  end

  private

  def bootstrap_and_select!(operator, token)
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
  end
end
