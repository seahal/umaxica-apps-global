# typed: false
# frozen_string_literal: true

module Identity
  module SecretCredentialCeremony
    class CandidateStore
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
        :transaction_id,
        :operation,
        :password_digest,
        :name,
        :enabled,
        :expires_at,
      )

      PREFIX = "identity:secret_credential_ceremony:candidate"

      # rubocop:disable ThreadSafety/ClassInstanceVariable
      def self.store
        @store || Rails.cache
      end
      # rubocop:enable ThreadSafety/ClassInstanceVariable

      def self.store!(**attributes)
        new.store!(**attributes)
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

      def store!(surface:, actor_ref:, session_ref:, transaction_id:, operation:, password_digest:, name:, enabled:,
                 expires_at:)
        raise Error, "secret credential password digest is required" if password_digest.blank?

        ref = SecureRandom.uuid
        payload = {
          "ref" => ref,
          "digest" => digest_for(surface, actor_ref, session_ref, transaction_id, operation, password_digest),
          "surface" => surface.to_s,
          "actor_ref" => actor_ref.to_s,
          "session_ref" => session_ref.to_s,
          "transaction_id" => transaction_id.to_s,
          "operation" => operation.to_s,
          "password_digest" => password_digest.to_s,
          "name" => name.to_s,
          "enabled" => ActiveModel::Type::Boolean.new.cast(enabled),
          "expires_at" => expires_at.to_i,
        }
        self.class.store.write(cache_key(ref), payload, expires_in: ttl_for(expires_at))
        candidate_from(payload)
      end

      def fetch!(ref)
        payload = self.class.store.read(cache_key(ref.to_s))
        raise Error, "secret credential candidate is not found" if payload.blank?

        candidate = candidate_from(payload)
        raise Error, "secret credential candidate is expired" if candidate.expires_at.to_i <= Time.current.to_i

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
          transaction_id: payload.fetch("transaction_id"),
          operation: payload.fetch("operation"),
          password_digest: payload.fetch("password_digest"),
          name: payload.fetch("name"),
          enabled: ActiveModel::Type::Boolean.new.cast(payload.fetch("enabled")),
          expires_at: Time.zone.at(payload.fetch("expires_at").to_i),
        )
      end

      def digest_for(surface, actor_ref, session_ref, transaction_id, operation, password_digest)
        data = [surface, actor_ref, session_ref, transaction_id, operation, password_digest].map(&:to_s).join(":")
        OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, data)
      end

      def ttl_for(expires_at)
        [expires_at.to_i - Time.current.to_i, 1].max.seconds
      end

      def cache_key(ref)
        "#{PREFIX}:#{ref}"
      end
    end
  end
end
