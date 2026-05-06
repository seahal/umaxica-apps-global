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
        initiate_sso!
      end
    end

    private

    def initiate_sso!(return_to: request.original_url)
      code_verifier = SecureRandom.urlsafe_base64(32)
      code_challenge = Base64.urlsafe_encode64(
        Digest::SHA256.digest(code_verifier),
        padding: false,
      )
      state = SecureRandom.urlsafe_base64(24)

      session[:oidc_code_verifier] = code_verifier
      session[:oidc_state] = state
      session[:oidc_return_to] = return_to

      redirect_to(oidc_authorize_url(code_challenge, state), allow_other_host: true)
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

    # Must be overridden in each RP's application controller
    def oidc_client_id
      raise NotImplementedError, "Subclass must define oidc_client_id"
    end
  end
end
