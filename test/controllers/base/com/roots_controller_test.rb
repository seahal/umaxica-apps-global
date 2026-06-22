# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("BASE_CORPORATE_URL", "base.com.localhost")
  end

  test "renders anonymous root" do
    host! @host

    get base_com_root_url(ri: "jp")

    assert_response :success
    assert_select "h1", text: "Base Com"
  end

  test "redirects signed-in visitor to dashboard" do
    host! @host
    visitor = create_verified_visitor_with_email(email_address: "base-com-root-#{SecureRandom.hex(4)}@example.com")

    get base_com_root_url(ri: "jp"), headers: as_visitor_headers(visitor, host: @host)

    assert_response :redirect
    assert_redirected_to base_com_dashboard_url(ri: "jp", host: @host)
  end
end
