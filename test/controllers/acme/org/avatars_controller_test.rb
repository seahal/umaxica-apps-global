# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Org::AvatarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
  end

  test "unauthenticated cannot access org avatar" do
    get acme_org_avatar_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :redirect
  end

  test "selector-only operator cannot access org avatar" do
    get acme_org_avatar_url(ri: "jp", host: @host), headers: as_staff_headers(@operator, host: @host)

    assert_response :redirect
    assert_match(%r{/selector}, response.location)
  end

  test "full login can show, edit, update and destroy own org avatar" do
    bootstrap_and_select!(@operator, @token)

    get acme_org_avatar_url(ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host)

    assert_response :success

    get edit_acme_org_avatar_url(ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host)

    assert_response :success

    patch acme_org_avatar_url(ri: "jp", host: @host),
          headers: as_staff_headers(@operator, host: @host)

    assert_response :redirect

    delete acme_org_avatar_url(ri: "jp", host: @host),
           headers: as_staff_headers(@operator, host: @host)

    assert_response :redirect
  end

  private

  def bootstrap_and_select!(operator, token)
    result = AcmeSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    AcmeSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    result
  end
end
