# typed: false
# frozen_string_literal: true

class IdentityTotpCeremonyCandidateStore
  class << self
    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    attr_writer :store
    # rubocop:enable ThreadSafety/ClassAndModuleAttributes
  end

  Candidate = Data.define(
    :ref,
    :digest,
    :surface,
    :actor_ref,
    :session_ref,
    :private_key,
    :title,
    :last_otp_at,
    :expires_at,
  )

  PREFIX = "identity:totp_ceremony:candidate"
  DEFAULT_TTL = IdentityTotpCeremonyTransaction::DEFAULT_TTL

  # rubocop:disable ThreadSafety/ClassInstanceVariable
  def self.store
    @store || Rails.cache
  end
  # rubocop:enable ThreadSafety/ClassInstanceVariable

  def self.store!(surface:, actor_ref:, session_ref:, private_key:, title:, last_otp_at:, expires_at:)
    new.store!(
      surface: surface,
      actor_ref: actor_ref,
      session_ref: session_ref,
      private_key: private_key,
      title: title,
      last_otp_at: last_otp_at,
      expires_at: expires_at,
    )
  end

  def self.fetch!(ref)
    new.fetch!(ref)
  end

  def self.consume!(ref)
    new.consume!(ref)
  end

  def self.delete(ref)
    new.delete(ref)
  end

  def store!(surface:, actor_ref:, session_ref:, private_key:, title:, last_otp_at:, expires_at:)
    raise IdentityTotpCeremonyContract::Error, "TOTP candidate secret is required" if private_key.blank?

    ref = SecureRandom.uuid
    payload = {
      "ref" => ref,
      "digest" => digest_for(private_key),
      "surface" => surface.to_s,
      "actor_ref" => actor_ref.to_s,
      "session_ref" => session_ref.to_s,
      "private_key" => private_key.to_s,
      "title" => title.to_s,
      "last_otp_at" => last_otp_at.to_i,
      "expires_at" => expires_at.to_i,
    }
    self.class.store.write(cache_key(ref), payload, expires_in: ttl_for(expires_at))
    candidate_from(payload)
  end

  def fetch!(ref)
    payload = self.class.store.read(cache_key(ref.to_s))
    raise IdentityTotpCeremonyContract::Error, "TOTP candidate is not found" if payload.blank?

    candidate = candidate_from(payload)
    raise IdentityTotpCeremonyContract::Error, "TOTP candidate is expired" if candidate.expires_at.to_i <= Time.current.to_i

    candidate
  end

  def consume!(ref)
    candidate = fetch!(ref)
    delete(ref)
    candidate
  end

  def delete(ref)
    self.class.store.delete(cache_key(ref.to_s))
  end

  private

  def candidate_from(payload)
    Candidate.new(
      ref: payload.fetch("ref"),
      digest: payload.fetch("digest"),
      surface: payload.fetch("surface"),
      actor_ref: payload.fetch("actor_ref"),
      session_ref: payload.fetch("session_ref"),
      private_key: payload.fetch("private_key"),
      title: payload["title"],
      last_otp_at: Time.zone.at(payload.fetch("last_otp_at").to_i),
      expires_at: Time.zone.at(payload.fetch("expires_at").to_i),
    )
  end

  def digest_for(private_key)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, private_key.to_s)
  end

  def ttl_for(expires_at)
    [expires_at.to_i - Time.current.to_i, 1].max.seconds
  end

  def cache_key(ref)
    "#{PREFIX}:#{ref}"
  end
end
