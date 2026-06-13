# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::OrgAuthorityRedirectsTest < ActionDispatch::IntegrationTest
  ROUTES = {
    sign_org_configuration_url: "/configuration",
    sign_org_accounts_url: "/accounts",
    sign_org_iam_index_url: "/iam",
    sign_org_system_index_url: "/system",
    sign_org_audit_index_url: "/audit",
    sign_org_support_index_url: "/support",
    sign_org_billing_index_url: "/billing",
  }.freeze

  test "sign org residual authority routes redirect to acme org" do
    ROUTES.each do |helper, path|
      get public_send(helper, host: ENV.fetch("SIGN_STAFF_URL"), ri: "jp")

      assert_response :see_other
      location = URI.parse(response.location)

      assert_equal ENV.fetch("ACME_STAFF_URL"), location.host
      assert_equal path, location.path
    end
  end

  test "sign ceremony entry routes remain on sign" do
    route = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("SIGN_STAFF_URL")}/sign/in/entrance",
      method: :get,
    )

    assert_equal "sign/org/sign/in/entrances", route.fetch(:controller)
    assert_equal "show", route.fetch(:action)
  end
end
