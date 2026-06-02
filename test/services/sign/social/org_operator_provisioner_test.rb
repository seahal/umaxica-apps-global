# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Social
    class OrgOperatorProvisionerTest < ActiveSupport::TestCase
      fixtures :operator_statuses, :operator_visibilities, :operator_google_identity_statuses,
               :operator_chronicle_events, :operator_chronicle_levels

      test "does not provision when allowlist is missing" do
        auth = google_auth(uid: "missing-allowlist-provisioner", email: "allowed@example.test")

        with_env("ORG_GOOGLE_SIGNUP_ALLOWLIST" => nil) do
          assert_no_difference ["Operator.count", "OperatorGoogleIdentity.count", "OperatorChronicle.count"] do
            assert_nil OrgOperatorProvisioner.call(auth)
          end
        end
      end

      test "provisions allowlisted operator identity with temporary marker" do
        auth = google_auth(uid: "allowlisted-provisioner", email: "Allowed@Example.Test")

        with_env("ORG_GOOGLE_SIGNUP_ALLOWLIST" => "allowed@example.test") do
          assert_difference("Operator.count", 1) do
            assert_difference("OperatorGoogleIdentity.count", 1) do
              assert_difference("OperatorChronicle.where(event_id: OperatorChronicleEvent::LOGIN_SUCCESS).count", 1) do
                staff = OrgOperatorProvisioner.call(auth)

                assert_equal OperatorStatus::ACTIVE, staff.status_id
              end
            end
          end
        end

        identity = OperatorGoogleIdentity.find_by!(uid: "allowlisted-provisioner", provider: "google_org")
        marker = OperatorChronicle.order(:id).last

        assert_equal identity.staff_id, marker.subject_id
        assert_equal "Operator", marker.subject_type
        assert_equal OrgOperatorProvisioner::SOURCE, marker.context.fetch("source")
        assert_equal true, marker.context.fetch("temporary_gateway")
        assert_equal "google_org", marker.context.fetch("provider")
      end

      test "does not duplicate operator identity or marker for duplicate uid" do
        staff = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
        identity = OperatorGoogleIdentity.create!(
          staff: staff,
          uid: "duplicate-provisioner",
          provider: "google_org",
          token: "old-token",
          token_expires_at: 1.week.from_now.to_i,
          status_id: OperatorGoogleIdentityStatus::ACTIVE,
        )
        auth = google_auth(uid: "duplicate-provisioner", token: "new-token", email: "allowed@example.test")

        with_env("ORG_GOOGLE_SIGNUP_ALLOWLIST" => "allowed@example.test") do
          assert_no_difference ["Operator.count", "OperatorGoogleIdentity.count", "OperatorChronicle.count"] do
            assert_equal staff, OrgOperatorProvisioner.call(auth, identity: identity)
          end
        end

        assert_equal "new-token", identity.reload.token
      end

      private

      def google_auth(uid:, token: "token", email:)
        OmniAuth::AuthHash.new(
          provider: "google_org",
          uid: uid,
          credentials: {
            token: token,
            refresh_token: "refresh-token",
            expires_at: 1.week.from_now.to_i,
          },
          info: {
            email: email,
          },
        )
      end

      def with_env(values)
        original = values.keys.index_with { |key| ENV[key] }
        values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
        yield
      ensure
        original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      end
    end
  end
end
