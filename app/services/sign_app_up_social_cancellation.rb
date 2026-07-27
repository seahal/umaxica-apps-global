# typed: false
# frozen_string_literal: true

class SignAppUpSocialCancellation
  SUPPORTED_PROVIDERS = {
    "apple" => ClientAppleIdentity,
    "google" => ClientGoogleIdentity,
  }.freeze

  def self.call(...)
    new(...).call
  end

  def initialize(cycle:)
    @cycle = cycle
  end

  def call
    return SignUpResult.build(status: :blocked, ticket: cycle, errors: ["ticket is required"]) unless cycle
    return SignUpResult.build(
      status: :blocked, ticket: cycle,
      errors: ["not a social sign-up"],
    ) unless social_cycle?

    return SignUpCancellation.call(cycle: cycle, actor_context: Actor.authn) if pre_confirmation_cycle?

    actor = Client.find_by(id: cycle.principal_id)
    return SignUpResult.build(
      status: :blocked, ticket: cycle,
      errors: ["pending actor is required"],
    ) unless pending_actor?(actor)

    identity = pending_identity_for(actor)
    return SignUpResult.build(
      status: :blocked, ticket: cycle,
      errors: ["pending social identity is required"],
    ) unless pending_identity?(
      identity, actor,
    )

    SignUpCancellation.call(cycle: cycle, actor_context: Actor.authn)
  end

  private

  attr_reader :cycle

  def social_cycle?
    SUPPORTED_PROVIDERS.key?(normalized_provider) &&
      cycle.social_entry_method?
  end

  def pre_confirmation_cycle?
    cycle.principal_id.blank? &&
      cycle.pending_contact_type.blank? &&
      cycle.pending_contact_id.blank?
  end

  def normalized_provider
    cycle.social_provider.presence || cycle.entry_method
  end

  def identity_class
    SUPPORTED_PROVIDERS.fetch(normalized_provider)
  end

  def pending_identity_for(actor)
    if ExternalAuthentication::IdentityRepositoryFactory.common_storage?
      identity = ExternalAuthentication::IdentityRepositoryFactory.current.build(normalized_provider).find_for_user(actor)
      return identity if identity && identity.id.to_s == cycle.pending_contact_id.to_s

      return nil
    end

    identity_class.find_by(id: cycle.pending_contact_id)
  end

  def pending_actor?(actor)
    actor&.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP
  end

  def pending_identity?(identity, actor)
    identity&.user_id == actor.id
  end
end
