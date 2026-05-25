# typed: false
# frozen_string_literal: true

module SignUp
  # Serializes concurrent sign-up registration attempts that share an
  # identifier digest (email address, telephone number, ...). Without
  # serialization, two sessions submitting the same identifier each pass
  # the existence check and race the unique index on `save!`; only one
  # survives and the loser surfaces a generic uniqueness validation
  # error mid-OTP-flow.
  #
  # Uses a PostgreSQL transaction-level advisory lock keyed on
  # `(namespace, digest)`. The key is hashed into a signed 64-bit integer
  # so it fits `pg_advisory_xact_lock(bigint)`. Locks release at
  # transaction commit or rollback.
  class EmailPendingGuard
    EMAIL_NAMESPACE = "sign_up:email_pending_guard"
    TELEPHONE_NAMESPACE = "sign_up:telephone_pending_guard"

    def self.with_lock(address_digest: nil, number_digest: nil, namespace: nil, model_class: nil, connection: nil)
      digest, ns = resolve_digest_and_namespace(address_digest, number_digest, namespace)
      raise ArgumentError, "digest is required" if digest.blank?
      raise ArgumentError, "block required" unless block_given?
      raise ArgumentError, "model_class or connection is required" unless model_class || connection

      key = lock_key(ns, digest)

      if model_class
        model_class.transaction do
          model_class.connection_pool.with_connection do |conn|
            conn.exec_query("SELECT pg_advisory_xact_lock(#{key.to_i})")
          end
          yield
        end
      else
        connection.transaction do
          connection.exec_query("SELECT pg_advisory_xact_lock(#{key.to_i})")
          yield
        end
      end
    end

    def self.lock_key(namespace, digest)
      hash = Digest::SHA256.hexdigest("#{namespace}:#{digest}")
      value = hash[0, 16].to_i(16)
      # Convert to signed 64-bit two's complement for PostgreSQL bigint.
      value -= 1 << 64 if value >= 1 << 63
      value
    end

    def self.resolve_digest_and_namespace(address_digest, number_digest, namespace)
      if address_digest.present?
        [address_digest, namespace || EMAIL_NAMESPACE]
      elsif number_digest.present?
        [number_digest, namespace || TELEPHONE_NAMESPACE]
      else
        [nil, namespace]
      end
    end
  end
end
