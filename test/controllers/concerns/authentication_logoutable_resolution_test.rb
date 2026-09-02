# typed: false
# frozen_string_literal: true

require "test_helper"

# Sign-out has to name the session it is closing even when the surface cannot
# resolve it the usual way. These are the fallbacks and the failure reports that
# stand between "the session lookup raised" and a logout that silently closes
# nothing: a resolution failure must surface as a named error, and a refresh
# cookie that cannot be parsed must resolve to no session rather than raise.
class AuthenticationLogoutableResolutionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include AuthenticationLogoutable

    attr_accessor :token_class_value, :token_class_raises, :cookie_jar, :refresh_record

    def token_class
      raise IOError, "token class unavailable" if token_class_raises

      token_class_value
    end

    def cookies = cookie_jar || {}

    # The surfaces that include this concern resolve the session themselves; the
    # fallbacks under test are what runs when that resolution yields nothing.
    def current_session = nil

    def find_refresh_token_record(_public_id) = refresh_record

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
  end

  test "a token class that cannot be resolved is reported as a named logout resolution failure" do
    @harness.token_class_raises = true

    error = assert_raises(StandardError) { @harness.invoke(:safe_token_class_for_logout) }

    assert_match(/token_class/, error.message)
  end

  test "a refresh cookie that cannot be parsed resolves to no session rather than raising" do
    parser =
      Class.new do
        def self.parse_refresh_token(_plain) = raise(ArgumentError, "malformed refresh token")
      end
    @harness.token_class_value = parser
    @harness.cookie_jar = { AuthenticationBase::REFRESH_COOKIE_KEY => "garbage" }

    assert_nil @harness.invoke(:session_token_from_refresh_cookie_for_logout)
    assert_nil @harness.invoke(:current_session_public_id_from_refresh_cookie_for_logout)
  end

  test "the session public id falls back to the one carried by the refresh cookie" do
    parser =
      Class.new do
        def self.parse_refresh_token(_plain) = ["public-id-from-cookie", "secret"]
      end
    @harness.token_class_value = parser
    @harness.cookie_jar = { AuthenticationBase::REFRESH_COOKIE_KEY => "refresh-token" }
    @harness.refresh_record = Struct.new(:public_id).new("public-id-from-cookie")

    assert_equal "public-id-from-cookie",
                 @harness.invoke(:current_session_public_id_from_refresh_cookie_for_logout)
    assert_equal "public-id-from-cookie",
                 @harness.invoke(:safe_current_session_public_id_for_logout)
  end

  test "a surface with neither a session nor a usable refresh cookie resolves to no session id" do
    parser =
      Class.new do
        def self.parse_refresh_token(_plain) = ["public-id-from-cookie", "secret"]
      end
    @harness.token_class_value = parser
    @harness.cookie_jar = { AuthenticationBase::REFRESH_COOKIE_KEY => "refresh-token" }
    @harness.refresh_record = nil

    assert_nil @harness.invoke(:safe_current_session_public_id_for_logout)
  end
end
