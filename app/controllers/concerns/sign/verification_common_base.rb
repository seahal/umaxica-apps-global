# typed: false
# frozen_string_literal: true

module Sign
  module VerificationCommonBase
    extend ActiveSupport::Concern

    private

    def require_ri!
      params.require(:ri)
    end

    def set_actor_token
      @actor_token = token_class.find_by!(public_id: current_session_public_id)
    end

    def actor_token
      @actor_token
    end

    def require_method_available!(method_sym)
      return true if available_step_up_methods.include?(method_sym)

      safe_redirect_to(
        verification_unavailable_redirect_path,
        fallback: "/verification",
        alert: I18n.t("auth.step_up.method_unavailable"),
      )
      false
    end

    def verification_scope
      current_step_up_session&.scope
    end

    def redirect_if_recent_verification_for_get!
      scope = verification_scope
      return false unless scope
      return false unless verification_recent_for_get?(scope: scope)

      consume_step_up_session!
      true
    end

    def redirect_if_recent_verification_for_post!
      scope = verification_scope
      return false unless scope
      return false unless verification_recent_for_post?(scope: scope)

      consume_step_up_session!
      true
    end

    def verification_unavailable_redirect_path
      raise NotImplementedError, "#{self.class} must define #verification_unavailable_redirect_path"
    end
  end
end
