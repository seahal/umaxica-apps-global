# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Settings::ConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    host! @host
  end

  test "sign settings connections index redirects to acme authority" do
    get sign_com_settings_connections_url(ri: "jp")

    assert_redirected_to acme_com_settings_connections_url(ri: "jp", host: @acme_host)
  end

  test "sign settings connection show redirects without loading connection" do
    get sign_com_settings_connection_url("missing", ri: "jp")

    assert_redirected_to acme_com_settings_connection_url("missing", ri: "jp", host: @acme_host)
  end

  test "sign settings connection destroy redirects without mutation" do
    connection = VisitorOidcConnection.create!(
      visitor: create_verified_visitor_with_email(email_address: "redirect-56ba5250@example.com"),
      client_id: "core_com",
    )

    delete sign_com_settings_connection_url(connection.public_id, ri: "jp")

    assert_redirected_to acme_com_settings_connection_url(connection.public_id, ri: "jp", host: @acme_host)
    assert_not_predicate connection.reload, :revoked?
  end
end
