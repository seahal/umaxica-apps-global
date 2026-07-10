# typed: false
# frozen_string_literal: true

module SignRequiresRecoveryPasscodes
  extend ActiveSupport::Concern

  private

  def require_recovery_passcodes_for_mfa_registration!
    return true unless recovery_passcodes_required_for_mfa_registration?
    return true if recovery_passcode_requirement_satisfied?

    @minimum_recovery_passcodes = SignRecoveryPasscodeRequirement::MINIMUM_USABLE_UNUSED_RECOVERY_PASSCODES
    @usable_unused_recovery_passcode_count = usable_unused_recovery_passcode_count
    @recovery_passcode_setup_url = recovery_passcode_setup_url
    render "shared/recovery_passcodes/required", status: :forbidden, formats: :html
    false
  end

  def recovery_passcode_requirement_satisfied?
    usable_unused_recovery_passcode_count >=
      SignRecoveryPasscodeRequirement::MINIMUM_USABLE_UNUSED_RECOVERY_PASSCODES
  end

  def recovery_passcodes_required_for_mfa_registration?
    recovery_passcode_requirement_active_strong_credential_count.positive?
  end

  def recovery_passcode_requirement_active_strong_credential_count
    1
  end

  def usable_unused_recovery_passcode_count
    @usable_unused_recovery_passcode_count ||= SignRecoveryPasscodeRequirement.usable_unused_count(
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
