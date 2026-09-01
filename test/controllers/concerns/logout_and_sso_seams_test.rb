# typed: false
# frozen_string_literal: true

require "test_helper"

# Two seams that decide which record a sign-out acts on and which redirect URI
# an SSO hand-off may use. Both must refuse rather than guess: an owner id that
# cannot be read from the token row falls back to the resolved resource, and a
# redirect URI the URI parser cannot read is a bad request, never a redirect.
class LogoutAndSsoSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "an sso redirect uri the parser cannot read is refused as a bad request" do
    client = Struct.new(:redirect_uris).new(["https://["])
    initiator = Class.new do
      include OidcSsoInitiator

      def request = Struct.new(:host).new("auth.app.localhost")

      def oidc_client_id = "sign-rp"
    end.new

    error =
      OidcClientRegistry.stub(:find!, client) do
        assert_raises(ActionController::BadRequest) do
          initiator.send(:oidc_callback_url)
        end
      end

    assert_match(/invalid/, error.message)
  end

  test "the owner of a session falls back to the resolved resource when the row names none" do
    resource = Struct.new(:id).new(42)
    logout = AuthenticationLogoutCurrentSession.new(resource: resource, token: nil)

    assert_equal 42, logout.send(:sign_out_principal_id, Object.new)
  end
end
