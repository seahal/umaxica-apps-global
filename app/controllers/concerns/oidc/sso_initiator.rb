# typed: false
# frozen_string_literal: true

module Oidc
  module SsoInitiator
    extend ActiveSupport::Concern

    # Override authenticate! from Authentication::Base to use OIDC flow on RP domains.
    # When a user is not logged in, instead of redirecting to sign-in directly,
    # we initiate the OIDC Authorization Code flow with PKCE.
    def authenticate!
      if logged_in?
        Sign::Risk::Enforcer.call(current_resource)
        return
      end

      if request.format.json?
        render json: { error: "Unauthorized" }, status: :unauthorized
      else
        Sign::Risk::Emitter.emit(
          "auth_required",
          ip: request&.remote_ip,
          user_agent: request&.user_agent,
          request_id: request&.request_id,
          path: request&.fullpath,
          method: request&.request_method,
        )
        rt = Base64.urlsafe_encode64(request.original_url)
        redirect_to(
          sign_in_url_with_return(rt),
          allow_other_host: true,
          alert: I18n.t("errors.messages.login_required"),
        )
      end
    end

    def sign_in_url_with_return(return_to)
      decoded_return_to = decode_return_to(return_to)
      initiate_oidc_session!(decoded_return_to)
    end

    private

    def initiate_sso!(return_to: request.original_url)
      initiate_oidc_session!(return_to)
    end

    def initiate_oidc_session!(return_to)
      code_verifier = SecureRandom.urlsafe_base64(32)
      code_challenge = Base64.urlsafe_encode64(
        Digest::SHA256.digest(code_verifier),
        padding: false,
      )
      state = SecureRandom.urlsafe_base64(24)

      session[:oidc_code_verifier] = code_verifier
      session[:oidc_state] = state
      session[:oidc_return_to] = return_to

      oidc_authorize_url(code_challenge, state)
    end

    def oidc_authorize_url(code_challenge, state)
      sign_host = oidc_sign_host
      protocol = request.protocol
      port = request.port
      port_suffix = [80, 443].include?(port) ? "" : ":#{port}"

      params = {
        response_type: "code",
        client_id: oidc_client_id,
        redirect_uri: oidc_callback_url,
        code_challenge: code_challenge,
        code_challenge_method: "S256",
        state: state,
      }

      "#{protocol}#{sign_host}#{port_suffix}/authorize?#{params.to_query}"
    end

    def oidc_callback_url
      protocol = request.protocol
      host = request.host
      port = request.port
      port_suffix = [80, 443].include?(port) ? "" : ":#{port}"
      "#{protocol}#{host}#{port_suffix}/auth/callback"
    end

    def oidc_sign_host
      ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    end

    def decode_return_to(return_to)
      Base64.urlsafe_decode64(return_to.to_s)
    rescue ArgumentError
      "/"
    end

    # Must be overridden in each RP's application controller
    def oidc_client_id
      raise NotImplementedError, "Subclass must define oidc_client_id"
    end
  end
end
