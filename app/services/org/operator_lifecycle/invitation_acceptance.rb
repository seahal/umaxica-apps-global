# typed: false
# frozen_string_literal: true

module Org
  module OperatorLifecycle
    class InvitationAcceptance
      Result =
        Data.define(:success, :invitation, :operator, :email, :error) do
          def success? = !!success
        end

      def self.call(invitation_code:)
        new(invitation_code: invitation_code).call
      end

      def initialize(invitation_code:)
        @invitation_code = invitation_code.to_s.downcase.strip
      end

      def call
        invitation = validate_invitation
        operator = nil
        email = nil
        failure_result = nil

        OrganizationInvitation.transaction do
          invitation.lock!
          if invitation.consumed?
            failure_result = failure(invitation: invitation, error: "Invitation has already been used")
          elsif invitation.expired?
            failure_result = failure(invitation: invitation, error: "Invitation has expired")
          else
            operator, email = create_operator_identity!(invitation)
            invitation.consume!
          end
        end

        return failure_result if failure_result

        Result.new(success: true, invitation: invitation, operator: operator, email: email, error: nil)
      rescue Org::RegistrationPolicy::InvitationRequiredError,
             Org::RegistrationPolicy::InvalidInvitationError,
             Org::RegistrationPolicy::InvitationExpiredError,
             Org::RegistrationPolicy::InvitationConsumedError => e
        failure(error: e.message)
      rescue ActiveRecord::RecordInvalid => e
        failure(invitation: invitation, error: e.record.errors.full_messages.to_sentence)
      rescue ActiveRecord::RecordNotUnique
        failure(invitation: invitation, error: "Invitation email is already registered")
      end

      private

      attr_reader :invitation_code

      def validate_invitation
        Org::RegistrationPolicy.validate!(invitation_code: invitation_code)
      end

      def create_operator_identity!(invitation)
        operator = nil
        email = nil

        OrgPrincipalRecord.transaction do
          operator = Operator.create!(
            status_id: OperatorIdentityStatus::ACTIVE,
            visibility_id: OperatorVisibility::STAFF,
          )
          email = operator.operator_emails.create!(
            raw_address: invitation.email,
            confirm_policy: true,
            staff_email_status_id: OperatorEmailStatus::VERIFIED,
            undeletable: true,
          )
        end

        create_operator_account!(operator)
        [operator, email]
      end

      def create_operator_account!(operator)
        OrgRpRecord.transaction do
          operator.create_rp_account! unless operator.rp_account
        end
      end

      def failure(invitation: nil, error:)
        Result.new(success: false, invitation: invitation, operator: nil, email: nil, error: error)
      end
    end
  end
end
