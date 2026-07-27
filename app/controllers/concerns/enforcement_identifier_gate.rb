# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Signup enforcement / Identifier attachment
# enforcement / Recovery enforcement: a reusable gate checking whether an
# in-force Identifier Effect blocks signup, identifier attachment, or
# recovery for a given normalized identifier. Realm-scoped by the caller's
# choice of `effect_class` -- an app check can never read com or org data
# (Realm isolation).
module EnforcementIdentifierGate
  extend ActiveSupport::Concern

  GATES = %i(registration_blocked attachment_blocked recovery_blocked).freeze

  def enforcement_blocks_email_registration?(effect_class:, realm:, email:)
    enforcement_blocks?(effect_class: effect_class, realm: realm, kind: :email, value: email, gate: :registration_blocked)
  end

  def enforcement_blocks_email_attachment?(effect_class:, realm:, email:)
    enforcement_blocks?(effect_class: effect_class, realm: realm, kind: :email, value: email, gate: :attachment_blocked)
  end

  def enforcement_blocks_email_recovery?(effect_class:, realm:, email:)
    enforcement_blocks?(effect_class: effect_class, realm: realm, kind: :email, value: email, gate: :recovery_blocked)
  end

  def enforcement_blocks_telephone_registration?(effect_class:, realm:, telephone:)
    enforcement_blocks?(
      effect_class: effect_class, realm: realm, kind: :telephone, value: telephone, gate: :registration_blocked,
    )
  end

  def enforcement_blocks_telephone_attachment?(effect_class:, realm:, telephone:)
    enforcement_blocks?(
      effect_class: effect_class, realm: realm, kind: :telephone, value: telephone, gate: :attachment_blocked,
    )
  end

  def enforcement_blocks_telephone_recovery?(effect_class:, realm:, telephone:)
    enforcement_blocks?(
      effect_class: effect_class, realm: realm, kind: :telephone, value: telephone, gate: :recovery_blocked,
    )
  end

  private

  def enforcement_blocks?(effect_class:, realm:, kind:, value:, gate:)
    raise ArgumentError, "Unsupported gate: #{gate}" unless EnforcementIdentifierGate::GATES.include?(gate)

    digest =
      case kind
      when :email then EnforcementIdentifierDigest.for_email(realm: realm, value: value)
      when :telephone then EnforcementIdentifierDigest.for_telephone(realm: realm, value: value)
      else raise ArgumentError, "Unsupported identifier kind: #{kind}"
      end
    return false unless digest

    effect_class.in_force
      .where(identifier_kind: digest[:identifier_kind], lookup_digest: digest[:lookup_digest])
      .exists?(gate => true)
  end
end
