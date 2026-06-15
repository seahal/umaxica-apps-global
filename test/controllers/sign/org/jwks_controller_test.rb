# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::JwksControllerTest < ActionDispatch::IntegrationTest
  test "sign org well-known jwks remains public" do
    get sign_org_well_known_jwks_url(host: ENV.fetch("ID_STAFF_URL", "id.org.localhost"), ri: "jp")

    assert_response :ok
    assert_predicate response.parsed_body.fetch("keys"), :present?
  end
end
