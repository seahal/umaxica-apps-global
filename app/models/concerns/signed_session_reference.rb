# typed: false
# frozen_string_literal: true

module SignedSessionReference
  extend ActiveSupport::Concern

  REF_EXPIRES_IN = 1.hour

  class_methods do
    def signed_ref_lookup_role
      :reading
    end

    def find_from_signed_ref(signed_ref)
      return nil if signed_ref.blank?

      data = Rails.application.message_verifier(:session_ref).verify(signed_ref)
      token_id = data[:id] || data["id"]
      public_id = data[:pid] || data["pid"]
      find_logic = -> { find_by(id: token_id, public_id: public_id) }

      role = Rails.env.test? ? :writing : signed_ref_lookup_role
      connection_owner.connected_to(role: role, &find_logic)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    private

    def connection_owner
      klass = self
      klass = klass.superclass until klass.connection_class? || klass == ApplicationRecord
      klass
    end
  end

  def signed_ref
    Rails.application.message_verifier(:session_ref).generate(
      { id: id, pid: public_id },
      expires_in: REF_EXPIRES_IN,
    )
  end
end
