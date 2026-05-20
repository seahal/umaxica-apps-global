# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      # Creates the pending client telephone signup state after HTTP validation has passed.
      class TelephoneSignupCreator
        # Outcome consumed by the surface controller.
        Result = Data.define(:status, :telephone, :session_payload)

        def self.call(telephone:, existing_telephone:, pending_public_id:)
          new(
            telephone: telephone,
            existing_telephone: existing_telephone,
            pending_public_id: pending_public_id,
          ).call
        end

        def initialize(telephone:, existing_telephone:, pending_public_id:)
          @telephone = telephone
          @existing_telephone = existing_telephone
          @pending_public_id = pending_public_id
          @result = nil
        end

        def call
          ClientTelephone.transaction do
            cleanup_pending_signup

            locked_existing = lock_existing_telephone
            if rate_limited_existing?(locked_existing)
              @result = Result.new(status: :rate_limited, telephone: @telephone, session_payload: nil)
              raise ActiveRecord::Rollback
            end

            remove_existing_unverified_telephones
            create_pending_telephone
          end

          @result
        end

        private

        def cleanup_pending_signup
          return if @pending_public_id.blank?

          pending_telephone = ClientTelephone.find_by(public_id: @pending_public_id)
          return unless pending_telephone

          pending_user = pending_telephone.user
          pending_telephone.destroy!
          pending_user.destroy! if pending_user&.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP
        end

        def lock_existing_telephone
          ClientTelephone.lock.find_by(id: @existing_telephone.id) if @existing_telephone
        end

        def rate_limited_existing?(locked_existing)
          return true if locked_existing&.locked?

          locked_existing&.user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP &&
            locked_existing.reregistration_window_active?
        end

        def remove_existing_unverified_telephones
          number_digest = @telephone.number_digest
          return if number_digest.blank?

          existing_telephones = ClientTelephone.where(
            number_digest: number_digest,
            user_identity_telephone_status_id: [ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP],
          ).to_a

          pending_user_ids = existing_telephones.filter_map(&:user_id)
          if pending_user_ids.any?
            Client.where(id: pending_user_ids, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
              .find_each(&:destroy!)
          end
          existing_telephones.each(&:destroy!)
        end

        def create_pending_telephone
          pending_user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
          @telephone.user = pending_user
          @telephone.user_telephone_status_id = ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP

          otp_code = Sign::TelephoneOtpDelivery.assign(@telephone)
          @telephone.save!
          Sign::TelephoneOtpDelivery.deliver!(@telephone, otp_code)

          @result = Result.new(
            status: :created,
            telephone: @telephone,
            session_payload: session_payload,
          )
        end

        def session_payload
          {
            public_id: @telephone.public_id,
            confirm_policy: boolean_value(@telephone.confirm_policy),
            confirm_using_mfa: boolean_value(@telephone.confirm_using_mfa),
            expires_at: @telephone.otp_expires_at.to_i,
          }
        end

        def boolean_value(value)
          ActiveModel::Type::Boolean.new.cast(value)
        end
      end
    end
  end
end
