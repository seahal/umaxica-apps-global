# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "com-org@example.com")
    @bootstrap = AcmeSelectorBootstrapAuthority.call(surface: :com, principal: @visitor)
  end

  test "index renders" do
    get acme_com_organizations_url(ri: "jp", host: @host), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :success
  end

  test "show resolves by public_id" do
    get "/organizations/#{@bootstrap.collective.public_id}?ri=jp", headers: as_visitor_headers(@visitor, host: @host)

    assert_response :success
  end

  test "unknown public_id returns 404" do
    get "/organizations/unknown-organization?ri=jp", headers: as_visitor_headers(@visitor, host: @host)

    assert_response :not_found
  end
end
