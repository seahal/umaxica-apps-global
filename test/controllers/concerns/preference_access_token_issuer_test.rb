# typed: false
# frozen_string_literal: true

require "test_helper"

# A preference access token is verified by this surface immediately after it is
# minted. A token that will not decode here would be handed to the browser and
# then rejected on every later request, so the cookie is cleared and the refresh
# is marked failed instead of leaving an unusable credential in place.
class PreferenceAccessTokenIssuerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include PreferenceAccessTokenIssuer

    attr_accessor :cookie_jar, :cleared, :legacy_cleared, :warnings

    def initialize
      @cookie_jar = {}
      @cleared = false
      @legacy_cleared = false
    end

    def request = Struct.new(:host).new("auth.app.localhost")

    def cookies = cookie_jar

    def access_token_cookie_name = :preference_access_token

    def preference_jwt_issuer_id = "surface:SIGN_APP"

    def preference_auth_cookie_options(**) = { httponly: true }

    def clear_legacy_preference_auth_cookies! = self.legacy_cleared = true

    def clear_preference_auth_cookies! = self.cleared = true

    def build_preferences_payload(_preference) = { "language" => "ja" }

    def write_public_option_cookies(_payload) = nil

    def rotate_preference_jti!(_preference) = nil

    def invoke(name, ...) = send(name, ...)
  end

  Preference = Struct.new(:jti, :public_id)

  setup do
    @harness = Harness.new
  end

  test "a token this surface cannot verify is cleared instead of being handed to the browser" do
    preference = Preference.new("jti-1", "pub-1")

    PreferenceToken.stub(:encode, "minted-token") do
      PreferenceToken.stub(:decode, nil) do
        assert_nil @harness.invoke(:issue_access_token_from, preference)
      end
    end

    assert @harness.cleared
    assert @harness.legacy_cleared
    assert @harness.instance_variable_get(:@preference_refresh_failed)
  end

  test "a token this surface verifies is kept and the payload is retained" do
    preference = Preference.new("jti-1", "pub-1")

    PreferenceToken.stub(:encode, "minted-token") do
      PreferenceToken.stub(:decode, { "language" => "ja" }) do
        @harness.invoke(:issue_access_token_from, preference)
      end
    end

    assert_not @harness.cleared
    assert_equal({ "language" => "ja" }, @harness.instance_variable_get(:@preference_payload))
    assert_equal "minted-token", @harness.cookie_jar[:preference_access_token].fetch(:value)
  end
end
