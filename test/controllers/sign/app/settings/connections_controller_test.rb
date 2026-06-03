# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Settings::ConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host! @host
  end

  test "sign settings connections index redirects to acme authority" do
    get sign_app_settings_connections_url(ri: "jp")

    assert_redirected_to acme_app_settings_connections_url(ri: "jp", host: @acme_host)
  end

  test "sign settings connection show redirects without loading connection" do
    get sign_app_settings_connection_url("missing", ri: "jp")

    assert_redirected_to acme_app_settings_connection_url("missing", ri: "jp", host: @acme_host)
  end

  test "sign settings connection destroy redirects without mutation" do
    connection = ClientOidcConnection.create!(user: clients(:one), client_id: "core_app")

    delete sign_app_settings_connection_url(connection.public_id, ri: "jp")

    assert_redirected_to acme_app_settings_connection_url(connection.public_id, ri: "jp", host: @acme_host)
    assert_not_predicate connection.reload, :revoked?
  end
end
