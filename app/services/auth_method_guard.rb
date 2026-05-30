# typed: false
# frozen_string_literal: true

class AuthMethodGuard
  VERIFIED_EMAIL_STATUSES = [
    ClientEmailStatus::VERIFIED,
    ClientEmailStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  VERIFIED_TELEPHONE_STATUSES = [
    ClientTelephoneStatus::VERIFIED,
    ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  VISITOR_VERIFIED_EMAIL_STATUSES = [
    VisitorEmailStatus::VERIFIED,
    VisitorEmailStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  VISITOR_VERIFIED_TELEPHONE_STATUSES = [
    VisitorTelephoneStatus::VERIFIED,
    VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze

  def self.remaining_count(actor, excluding: nil)
    Authentication::CredentialInventory.call(actor, excluding: excluding, reload: true).aal1_method_count
  end

  def self.last_method?(actor, excluding: nil)
    remaining_count(actor, excluding: excluding).zero?
  end

  def self.can_remove_passkey?(actor, passkey)
    inventory = Authentication::CredentialInventory.call(actor, excluding: passkey, reload: true)
    inventory.retains_aal1? && inventory.retains_aal2?
  end

  def self.can_remove_email?(actor, email)
    inventory = Authentication::CredentialInventory.call(actor, excluding: email, reload: true)
    inventory.retains_contactability? && inventory.retains_aal1? && inventory.retains_aal2?
  end

  def self.can_remove_telephone?(actor, telephone)
    Authentication::CredentialInventory.call(actor, excluding: telephone, reload: true).retains_contactability?
  end

  def self.can_remove_totp?(actor, totp)
    Authentication::CredentialInventory.call(actor, excluding: totp, reload: true).retains_aal2?
  end

  def self.verified_emails_count(actor, excluding: nil)
    if actor.respond_to?(:client_emails)
      scope = actor.client_emails.where(user_email_status_id: VERIFIED_EMAIL_STATUSES)
      scope = scope.where.not(id: excluding.id) if excluding_record?(excluding, "ClientEmail")
      return scope.count
    end

    if actor.respond_to?(:visitor_emails)
      scope = actor.visitor_emails.where(visitor_email_status_id: VISITOR_VERIFIED_EMAIL_STATUSES)
      scope = scope.where.not(id: excluding.id) if excluding_record?(excluding, "VisitorEmail")
      return scope.count
    end

    0
  end

  def self.verified_telephones_count(actor, excluding: nil)
    if actor.respond_to?(:client_telephones)
      scope = actor.client_telephones.where(user_telephone_status_id: VERIFIED_TELEPHONE_STATUSES)
      scope = scope.where.not(id: excluding.id) if excluding_record?(excluding, "ClientTelephone")
      return scope.count
    end

    if actor.respond_to?(:visitor_telephones)
      scope = actor.visitor_telephones.where(visitor_telephone_status_id: VISITOR_VERIFIED_TELEPHONE_STATUSES)
      scope = scope.where.not(id: excluding.id) if excluding_record?(excluding, "VisitorTelephone")
      return scope.count
    end

    0
  end

  def self.active_passkeys_count(actor, excluding: nil)
    if actor.respond_to?(:client_passkeys)
      scope = actor.client_passkeys.where(status_id: ClientPasskeyStatus::ACTIVE)
      scope = scope.where.not(id: excluding.id) if excluding_record?(excluding, "ClientPasskey")
      return scope.count
    end

    if actor.respond_to?(:visitor_passkeys)
      scope = actor.visitor_passkeys.where(status_id: VisitorPasskeyStatus::ACTIVE)
      scope = scope.where.not(id: excluding.id) if excluding_record?(excluding, "VisitorPasskey")
      return scope.count
    end

    0
  end

  def self.active_social_count(actor)
    count = 0
    if actor.respond_to?(:user_google_identity) &&
        actor.user_google_identity&.status_id == ClientGoogleIdentityStatus::ACTIVE
      count += 1
    end
    if actor.respond_to?(:user_apple_identity) &&
        actor.user_apple_identity&.status_id == ClientAppleIdentityStatus::ACTIVE
      count += 1
    end
    count
  end

  private_class_method :verified_emails_count,
                       :verified_telephones_count,
                       :active_passkeys_count,
                       :active_social_count

  def self.excluding_record?(record, class_name)
    record.present? && record.respond_to?(:id) && record.class.name == class_name
  end

  private_class_method :excluding_record?
end
