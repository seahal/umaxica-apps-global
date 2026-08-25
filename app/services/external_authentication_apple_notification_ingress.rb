# typed: false
# frozen_string_literal: true

class ExternalAuthenticationAppleNotificationIngress
  Result = Data.define(:status, :event)

  def self.call(...)
    new(...).call
  end

  def initialize(jws:, verifier: nil, repository: ExternalAuthentication::IdentityRepositoryFactory.current)
    @jws = jws
    @verifier = verifier || ExternalAuthentication::AppleNotificationVerifier.from_credentials(jws: jws)
    @repository = repository
  end

  def call
    notification = verifier.call
    identity = repository.build("apple").find_by_subject(notification.subject, lock: false)
    event, created = create_event(notification, identity)
    return Result.new(status: :duplicate, event: event) unless created

    AppleNotificationProcessingJob.perform_later(event.jti)
    Result.new(status: :accepted, event: event)
  end

  private

  attr_reader :verifier, :repository

  def create_event(notification, identity)
    attributes = {
      jti: notification.jti,
      event_type: notification.event_type,
      client: identity&.user,
      received_at: Time.current,
      occurred_at: notification.occurred_at,
    }
    attributes[:client_external_identity] = identity if identity.is_a?(ClientExternalIdentity)

    [ClientAppleNotificationEvent.create!(**attributes), true]
  rescue ActiveRecord::RecordNotUnique
    [ClientAppleNotificationEvent.find_by!(jti: notification.jti), false]
  rescue ActiveRecord::RecordInvalid => e
    raise unless e.record.errors.of_kind?(:jti, :taken)

    [ClientAppleNotificationEvent.find_by!(jti: notification.jti), false]
  end
end
