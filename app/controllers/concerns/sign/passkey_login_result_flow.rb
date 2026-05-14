# typed: false
# frozen_string_literal: true

module Sign
  module PasskeyLoginResultFlow
    extend ActiveSupport::Concern

    private

    def handle_login_result(result)
      return if handle_domain_specific_login_status(result)
      return render_passkey_success(result) if result[:status] == :success

      render_error("errors.login_failed", :unprocessable_content)
    end

    def render_passkey_success(result)
      if passkey_success_restricted?(result)
        return render_passkey_restricted_success(result)
      end

      rt = retrieve_redirect_parameter_for_checkpoint if respond_to?(:retrieve_redirect_parameter_for_checkpoint, true)
      render json: {
        status: "ok",
        access_token: result[:access_token],
        token_type: result[:token_type],
        # API contract: this is the actual remaining JWT lifetime in seconds.
        # It may be shorter than the default access TTL when the backing token
        # has an earlier revocation boundary.
        expires_in: result[:expires_in],
        redirect_url: sign_in_sequence_redirect_path(rt: rt, default_path: passkey_default_redirect_url),
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
