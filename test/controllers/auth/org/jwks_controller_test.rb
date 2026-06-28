# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::JwksControllerTest < ActionDispatch::IntegrationTest
  test "sign org well-known jwks remains public" do
    get auth_org_well_known_jwks_url(host: ENV.fetch("AUTH_STAFF_URL"), ri: "jp")

    assert_response :ok
    assert_predicate response.parsed_body.fetch("keys"), :present?
  end
end
