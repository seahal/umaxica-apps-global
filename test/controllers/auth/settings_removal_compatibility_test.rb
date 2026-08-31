# typed: false
# frozen_string_literal: true

require "test_helper"

# The `.../removal` POST endpoints are compatibility shims kept alive after
# credential lifecycle moved: they answer with a 303 to the resource's canonical
# settings page on the surface the request already came from, carrying the region
# across. All three surfaces share SignAuthorityRedirect, so each one is pinned here.
class AuthSettingsRemovalCompatibilityTest < ActionDispatch::IntegrationTest
  fixtures :clients, :visitors, :operators

  test "the app passkey removal endpoint redirects to the canonical settings page" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    post auth_app_settings_passkey_removal_url("pk-public-id", ri: "jp", host: host),
         headers: as_user_headers(clients(:one), host: host)

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal host, location.host
    assert_equal "/settings/passkeys/pk-public-id", location.path
    assert_equal "jp", Rack::Utils.parse_nested_query(location.query.to_s)["ri"]
  end

  test "the com passkey removal endpoint keeps the query it was given" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    visitor = visitors(:reserved_visitor)
    address = "com-removal-#{SecureRandom.hex(4)}@example.com"
    VisitorEmail.create!(
      visitor_id: visitor.id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    post auth_com_settings_passkey_removal_url("pk-public-id", ri: "jp", from: "list", host: host),
         headers: as_visitor_headers(visitor, host: host)

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal host, location.host
    assert_equal "/settings/passkeys/pk-public-id", location.path
    assert_equal "list", query["from"]
    assert_equal "jp", query["ri"]
  end

  test "the org passkey removal endpoint redirects to the canonical settings page" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    post auth_org_settings_passkey_removal_url("pk-public-id", ri: "jp", host: host),
         headers: as_staff_headers(operators(:one), host: host)

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal host, location.host
    assert_equal "/settings/passkeys/pk-public-id", location.path
  end

  test "an unauthenticated removal request never reaches the redirect" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    post auth_app_settings_passkey_removal_url("pk-public-id", ri: "jp", host: host),
         headers: { "Client-Agent" => "Mozilla/5.0", "Host" => host }

    assert_not_equal "/settings/passkeys/pk-public-id", URI.parse(response.location.to_s).path
  end
end
