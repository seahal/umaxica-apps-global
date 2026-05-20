# typed: false
# frozen_string_literal: true

module StepUp
  # Persistent credential state only. Transient cooldowns and ticket lockout
  # belong in AvailableMethods.
  module ConfiguredMethods
    module_function

    def call(subject)
      return [] unless subject

      Authentication::CredentialInventory.call(subject).aal2_methods
    end

    def configured_email?(subject)
      call(subject).include?(:email_otp)
    end

    def configured_passkey?(subject)
      call(subject).include?(:passkey)
    end

    def configured_totp?(subject)
      call(subject).include?(:totp)
    end
  end
end
