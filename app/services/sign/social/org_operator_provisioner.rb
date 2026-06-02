# typed: false
# frozen_string_literal: true

module Sign
  module Social
    # TEMP(org-google-social-gateway): remove before production cleanup
    class OrgOperatorProvisioner
      SOURCE = "org_google_social_temporary_gateway"

      def self.call(auth_hash, identity: nil)
        new(auth_hash, identity: identity).call
      end

      def initialize(auth_hash, identity: nil)
        @auth_hash = auth_hash
        @identity = identity
      end

      def call
        return nil if identity && !identity.active?

        staff = nil
        OrgPrincipalRecord.connected_to(role: :writing) do
          OrgPrincipalRecord.transaction do
            staff = provision_or_reuse_staff!
          end
        end
        record_provisioning_marker!(staff) if @provisioned
        staff
      end

      private

      attr_reader :auth_hash, :identity

      def provision_or_reuse_staff!
        google_identity = identity || find_identity
        if google_identity&.active?
          google_identity.update_from_auth_hash!(auth_hash)
          return google_identity.staff
        end

        return nil if google_identity
        return nil unless Sign::Social::TemporarySignupGate.provisioning_allowed?(email_from_auth)

        staff = Operator.create!(
          status_id: OperatorStatus::ACTIVE,
          visibility_id: OperatorVisibility::STAFF,
        )
        google_identity = OperatorGoogleIdentity.find_or_create_from_auth_hash(auth_hash)
        google_identity.staff = staff
        google_identity.status_id = OperatorGoogleIdentityStatus::ACTIVE
        google_identity.save!
        @provisioned = true
        staff
      end

      def find_identity
        uid = OperatorGoogleIdentity.extract_uid(auth_hash)
        provider = OperatorGoogleIdentity.provider_from_auth(auth_hash)
        return nil if uid.blank? || provider.blank?

        OperatorGoogleIdentity.lock.find_by(uid: uid, provider: provider)
      end

      def record_provisioning_marker!(staff)
        ChronicleRecord.connected_to(role: :writing) do
          OperatorChronicle.create!(
            actor_type: "Operator",
            actor_id: staff.id,
            event_id: OperatorChronicleEvent::LOGIN_SUCCESS,
            level_id: OperatorChronicleLevel::NOTHING,
            subject_id: staff.id,
            subject_type: "Operator",
            occurred_at: Time.current,
            context: {
              source: SOURCE,
              temporary_gateway: true,
              auth_method: "social",
              provider: "google_org",
            },
          )
        end
      end

      def email_from_auth
        info =
          if auth_hash.respond_to?(:dig)
            auth_hash.dig("info") || auth_hash.dig(:info)
          elsif auth_hash.respond_to?(:info)
            auth_hash.info
          end

        if info.respond_to?(:[])
          info["email"] || info[:email]
        elsif info.respond_to?(:email)
          info.email
        end
      end
    end
  end
end
