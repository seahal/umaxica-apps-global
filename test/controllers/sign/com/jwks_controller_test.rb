# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::JwksControllerTest < ActionDispatch::IntegrationTest
  test "sign com well-known jwks remains public" do
    get sign_com_well_known_jwks_url(host: ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"), ri: "jp")

    assert_response :ok
    assert_predicate response.parsed_body.fetch("keys"), :present?
  end
end
