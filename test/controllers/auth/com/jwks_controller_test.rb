# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::JwksControllerTest < ActionDispatch::IntegrationTest
  test "sign com well-known jwks remains public" do
    get auth_com_well_known_jwks_url(host: ENV.fetch("AUTH_CORPORATE_URL"), ri: "jp")

    assert_response :ok
    assert_predicate response.parsed_body.fetch("keys"), :present?
  end
end
