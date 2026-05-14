# typed: false
# frozen_string_literal: true

class AuthMethodGuard
  VERIFIED_EMAIL_STATUSES = [
    UserEmailStatus::VERIFIED,
    UserEmailStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  VERIFIED_TELEPHONE_STATUSES = [
    UserTelephoneStatus::VERIFIED,
    UserTelephoneStatus::VERIFIED_WITH_SIGN_UP,
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
    count = 0

    if actor.respond_to?(:user_social_google)
      google = actor.user_social_google
      if google&.status_id == UserSocialGoogleStatus::ACTIVE
        count += 1
        count -= 1 if excluding.is_a?(UserSocialGoogle) && excluding.id == google.id
      end
    end

    if actor.respond_to?(:user_social_apple)
      apple = actor.user_social_apple
      if apple&.status_id == UserSocialAppleStatus::ACTIVE
        count += 1
        count -= 1 if excluding.is_a?(UserSocialApple) && excluding.id == apple.id
      end
    end

    count += verified_emails_count(actor, excluding: excluding)
    count += verified_telephones_count(actor, excluding: excluding)
    count += active_passkeys_count(actor, excluding: excluding)

    [count, 0].max
  end

  def self.last_method?(actor, excluding: nil)
    remaining_count(actor, excluding: excluding).zero?
  end

  def self.can_remove_passkey?(actor, passkey)
    remaining_passkeys = active_passkeys_count(actor, excluding: passkey)
    return true if remaining_passkeys.positive?

    verified_emails_count(actor).positive? || active_social_count(actor).positive?
  end

  def self.can_remove_email?(actor, email)
    remaining_emails = verified_emails_count(actor, excluding: email)
    return true if remaining_emails.positive?

    remaining_telephones = verified_telephones_count(actor)
    return false if remaining_telephones.zero?

    active_passkeys_count(actor).positive? || active_social_count(actor).positive?
  end

  def self.can_remove_telephone?(actor, telephone)
    remaining_telephones = verified_telephones_count(actor, excluding: telephone)
    return true if remaining_telephones.positive?

    verified_emails_count(actor).positive?
  end

  def self.verified_emails_count(actor, excluding: nil)
    if actor.respond_to?(:user_emails)
      scope = actor.user_emails.where(user_email_status_id: VERIFIED_EMAIL_STATUSES)
      scope = scope.where.not(id: excluding.id) if excluding.is_a?(UserEmail)
      return scope.count
    end

    if actor.respond_to?(:visitor_emails)
      scope = actor.visitor_emails.where(visitor_email_status_id: VISITOR_VERIFIED_EMAIL_STATUSES)
      scope = scope.where.not(id: excluding.id) if excluding.is_a?(VisitorEmail)
      return scope.count
    end

    0
  end

  def self.verified_telephones_count(actor, excluding: nil)
    if actor.respond_to?(:user_telephones)
      scope = actor.user_telephones.where(user_telephone_status_id: VERIFIED_TELEPHONE_STATUSES)
      scope = scope.where.not(id: excluding.id) if excluding.is_a?(UserTelephone)
      return scope.count
    end

    if actor.respond_to?(:visitor_telephones)
      scope = actor.visitor_telephones.where(visitor_telephone_status_id: VISITOR_VERIFIED_TELEPHONE_STATUSES)
      scope = scope.where.not(id: excluding.id) if excluding.is_a?(VisitorTelephone)
      return scope.count
    end

    0
  end

  def self.active_passkeys_count(actor, excluding: nil)
    if actor.respond_to?(:user_passkeys)
      scope = actor.user_passkeys.where(status_id: UserPasskeyStatus::ACTIVE)
      scope = scope.where.not(id: excluding.id) if excluding.is_a?(UserPasskey)
      return scope.count
    end

    if actor.respond_to?(:visitor_passkeys)
      scope = actor.visitor_passkeys.where(status_id: VisitorPasskeyStatus::ACTIVE)
      scope = scope.where.not(id: excluding.id) if excluding.is_a?(VisitorPasskey)
      return scope.count
    end

    0
  end

  def self.active_social_count(actor)
    count = 0
    if actor.respond_to?(:user_social_google) &&
        actor.user_social_google&.status_id == UserSocialGoogleStatus::ACTIVE
      count += 1
    end
    if actor.respond_to?(:user_social_apple) &&
        actor.user_social_apple&.status_id == UserSocialAppleStatus::ACTIVE
      count += 1
    end
    count
  end

  private_class_method :verified_emails_count,
                       :verified_telephones_count,
                       :active_passkeys_count,
                       :active_social_count
end
