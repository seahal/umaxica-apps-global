# typed: false
# frozen_string_literal: true

module StepUp
  # Persistent credential state only. Transient cooldowns and ticket lockout
  # belong in AvailableMethods.
  module ConfiguredMethods
    module_function

    def call(subject)
      return [] unless subject

      methods = []
      methods << :email_otp if configured_email?(subject)
      methods << :passkey if configured_passkey?(subject)
      methods << :totp if configured_totp?(subject)
      methods
    end

    def configured_email?(subject)
      if subject.respond_to?(:user_emails)
        return subject.user_emails.exists?(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES)
      end

      if subject.respond_to?(:visitor_emails)
        return subject.visitor_emails.exists?(visitor_email_status_id: AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES)
      end

      if subject.respond_to?(:staff_emails)
        return subject.staff_emails.exists?(
          staff_identity_email_status_id: [
            OperatorEmailStatus::ACTIVE,
            OperatorEmailStatus::VERIFIED,
          ],
        )
      end

      false
    end

    def configured_passkey?(subject)
      return subject.user_passkeys.active.exists? if subject.respond_to?(:user_passkeys)
      return subject.visitor_passkeys.active.exists? if subject.respond_to?(:visitor_passkeys)
      return subject.staff_passkeys.active.exists? if subject.respond_to?(:staff_passkeys)

      false
    end

    def configured_totp?(subject)
      if subject.respond_to?(:user_one_time_passwords)
        return subject.user_one_time_passwords.exists?(
          user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
        )
      end

      false
    end
  end
end
