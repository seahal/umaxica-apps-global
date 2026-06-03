# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Settings::ConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    host! @host
  end

  test "sign settings connections index redirects to acme authority" do
    get sign_org_settings_connections_url(ri: "jp")

    assert_redirected_to acme_org_settings_connections_url(ri: "jp", host: @acme_host)
  end

  test "sign settings connection show redirects without loading connection" do
    get sign_org_settings_connection_url("missing", ri: "jp")

    assert_redirected_to acme_org_settings_connection_url("missing", ri: "jp", host: @acme_host)
  end

  test "sign settings connection destroy redirects without mutation" do
    connection = OperatorOidcConnection.create!(staff: operators(:one), client_id: "core_org")

    delete sign_org_settings_connection_url(connection.public_id, ri: "jp")

    assert_redirected_to acme_org_settings_connection_url(connection.public_id, ri: "jp", host: @acme_host)
    assert_not_predicate connection.reload, :revoked?
  end
end
