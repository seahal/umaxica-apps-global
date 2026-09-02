# typed: false
# frozen_string_literal: true

require "test_helper"

# Defaults and delegations that only run when a surface supplies nothing of its
# own: the visitor surface defers its session cap for every other principal
# kind, the RP identity state falls back to the active id when no state
# association is declared, and the DBSC endpoint resolves no resource at all
# when the request carries no access cookie.
class SurfaceSeamDefaultsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "the visitor session cap applies to visitors and defers to the base rule otherwise" do
    subject = Class.new { include AuthenticationVisitor }.new
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)

    assert_equal VisitorToken::MAX_SESSIONS_PER_VISITOR, subject.send(:max_sessions_for_resource, visitor)
    # Any other principal kind is left to the shared rule this concern is layered
    # over, which is what the visitor cap must not silently apply to.
    assert_not_equal VisitorToken::MAX_SESSIONS_PER_VISITOR,
                     subject.send(:max_sessions_for_resource, Object.new)
  end

  test "an rp identity class with no state association falls back to the active status id" do
    identity_class =
      Class.new do
        def self.reflect_on_association(_name) = nil
      end
    subject = Class.new do
      include OidcRpIdentityProvisioning

      define_method(:rp_identity_class) { identity_class }
    end.new

    assert_equal 1, subject.send(:rp_identity_active_status_id)
  end

  test "the dbsc endpoint resolves no resource when the request carries no access cookie" do
    subject = Class.new do
      include SignDbscRegistrationEndpoint

      def extract_access_token(_key) = nil
    end.new

    assert_nil subject.send(:load_current_resource)
  end

  test "the preference verification key is resolved for the active key id" do
    assert_equal PreferenceJwtConfiguration.public_key_for(PreferenceJwtConfiguration.active_kid),
                 PreferenceJwtConfiguration.public_key
  end
end
