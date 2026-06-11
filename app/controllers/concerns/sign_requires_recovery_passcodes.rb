# typed: false
# frozen_string_literal: true

module SignRequiresRecoveryPasscodes
  extend ActiveSupport::Concern

  private

  def require_recovery_passcodes_for_mfa_registration!
    return true if recovery_passcode_requirement_satisfied?

    @minimum_recovery_passcodes = Sign::RecoveryPasscodeRequirement::MINIMUM_USABLE_UNUSED_RECOVERY_PASSCODES
    @usable_unused_recovery_passcode_count = usable_unused_recovery_passcode_count
    @recovery_passcode_setup_url = recovery_passcode_setup_url
    render "shared/recovery_passcodes/required", status: :forbidden, formats: :html
    false
  end

  def recovery_passcode_requirement_satisfied?
    usable_unused_recovery_passcode_count >=
      Sign::RecoveryPasscodeRequirement::MINIMUM_USABLE_UNUSED_RECOVERY_PASSCODES
  end

  def usable_unused_recovery_passcode_count
    @usable_unused_recovery_passcode_count ||= Sign::RecoveryPasscodeRequirement.usable_unused_count(
      actor: recovery_passcode_requirement_actor,
      credential_class: recovery_passcode_requirement_credential_class,
    )
  end

  def recovery_passcode_requirement_actor
    raise NotImplementedError, "#{self.class} must define #recovery_passcode_requirement_actor"
  end

  def recovery_passcode_requirement_credential_class
    raise NotImplementedError, "#{self.class} must define #recovery_passcode_requirement_credential_class"
  end

  def recovery_passcode_setup_url
    raise NotImplementedError, "#{self.class} must define #recovery_passcode_setup_url"
  end
end
