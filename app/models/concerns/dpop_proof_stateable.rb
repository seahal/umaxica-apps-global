# typed: false
# frozen_string_literal: true

module DpopProofStateable
  extend ActiveSupport::Concern

  TTL_SECONDS = 300

  included do
    scope :active_at, ->(time) { where(arel_table[:expires_at].gt(time)) }
  end

  class_methods do
    def record_jti!(jti:, jkt:, htm:, htu:, now: Time.current)
      return false if jti.blank?

      create!(
        jti: jti,
        jkt: jkt,
        htm: htm,
        htu: htu,
        seen_at: now,
        expires_at: now + TTL_SECONDS.seconds,
      )
      true
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      false
    end

    def issue_nonce!(now: Time.current)
      nonce = SecureRandom.urlsafe_base64(32)
      create!(nonce: nonce, seen_at: now, expires_at: now + TTL_SECONDS.seconds)
      nonce
    end

    def consume_nonce!(nonce, now: Time.current)
      return false if nonce.blank?

      state = active_at(now).lock.find_by(nonce: nonce, nonce_used_at: nil)
      return false unless state

      state.update!(nonce_used_at: now)
      true
    end
  end
end
