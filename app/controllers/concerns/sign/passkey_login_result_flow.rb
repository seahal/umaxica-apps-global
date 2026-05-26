# typed: false
# frozen_string_literal: true

module Sign
  module PasskeyLoginResultFlow
    extend ActiveSupport::Concern

    private

    def handle_login_result(result)
      sign_in_result = sign_in_result_from_session_result(result)
      return if handle_domain_specific_login_status(result)
      return render_passkey_restricted_success(result) if sign_in_result.session_limit_pending?
      return render_passkey_success(result, sign_in_result: sign_in_result) if sign_in_result.success?

      render_error("errors.login_failed", :unprocessable_content)
    end

    def render_passkey_success(result, sign_in_result:)
      pt = retrieve_pt_for_checkpoint if respond_to?(:retrieve_pt_for_checkpoint, true)
      render json: {
        status: "ok",
        access_token: result[:access_token],
        token_type: result[:token_type],
        # API contract: this is the actual remaining JWT lifetime in seconds.
        # It may be shorter than the default access TTL when the backing token
        # has an earlier revocation boundary.
        expires_in: result[:expires_in],
        redirect_url: sign_in_sequence_redirect_path(pt: pt, default_path: passkey_default_redirect_url),
        dbsc: result[:dbsc],
      }, status: :ok
    end

    def handle_domain_specific_login_status(_result)
      false
    end

    def passkey_success_restricted?(_result)
      false
    end

    def render_passkey_restricted_success(_result)
      raise NotImplementedError, "#{self.class} must define #render_passkey_restricted_success"
    end

    def passkey_checkpoint_redirect_url
      raise NotImplementedError, "#{self.class} must define #passkey_checkpoint_redirect_url"
    end

    alias_method :passkey_bulletin_redirect_url, :passkey_checkpoint_redirect_url

    def passkey_default_redirect_url
      raise NotImplementedError, "#{self.class} must define #passkey_default_redirect_url"
    end
  end
end
