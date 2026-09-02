# typed: false
# frozen_string_literal: true

require "test_helper"

# Redirects from a credential surface to the identity authority must land on the
# authority host of the *same* surface: sending an org controller to the app
# authority would carry a staff ceremony onto the end-user surface. The mapping
# is taken from the controller's own namespace, and a namespace outside the
# three surfaces stays on the host that is already answering rather than
# guessing one.
class SignAcmeAuthorityRedirectTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(name)
    Class.new do
      include SignAcmeAuthorityRedirect

      define_singleton_method(:name) { name }

      def request = Struct.new(:host).new("unmapped.example")

      def invoke(method_name, ...) = send(method_name, ...)
    end.new
  end

  test "each surface resolves the authority host of its own surface" do
    assert_equal ENV.fetch("PRIVATE_BASE_SERVICE_URL"),
                 harness_for("Auth::App::SettingsController").invoke(:base_authority_host)
    assert_equal ENV.fetch("PRIVATE_BASE_CORPORATE_URL"),
                 harness_for("Auth::Com::SettingsController").invoke(:base_authority_host)
    assert_equal ENV.fetch("PRIVATE_BASE_STAFF_URL"),
                 harness_for("Auth::Org::SettingsController").invoke(:base_authority_host)
  end

  test "a controller outside the three surfaces stays on the host already answering" do
    assert_equal "unmapped.example", harness_for("Palm::App::RootsController").invoke(:base_authority_host)
  end

  test "the acme aliases resolve to the same host and query as the base authority" do
    harness = harness_for("Auth::Com::SettingsController")

    assert_equal harness.invoke(:base_authority_host), harness.invoke(:acme_authority_host)
    assert_equal harness.invoke(:base_authority_query, { ri: "jp" }),
                 harness.invoke(:acme_authority_query, { ri: "jp" })
  end
end
