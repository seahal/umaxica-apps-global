# typed: false
# frozen_string_literal: true

module Oidc
  module SsoInitiator
    extend ActiveSupport::Concern

    def authenticate!
      if logged_in?
        Sign::Risk::Enforcer.call(current_resource)
        return
      end

      return render(json: { error: "Unauthorized" }, status: :unauthorized) if request.format.json?

      Sign::Risk::Emitter.emit(
        "auth_required",
        ip: request&.remote_ip,
        user_agent: request&.user_agent,
        request_id: request&.request_id,
        path: request&.fullpath,
        method: request&.request_method,
      )
      redirect_to(sign_in_url_with_return(encoded_return_to(request.original_url)), allow_other_host: true)
    end

    def sign_in_url_with_return(return_to)
      initiate_oidc_session!(return_to: decode_return_to(return_to))
    end

    private

    def initiate_oidc_session!(return_to: request.original_url, screen_hint: nil)
      verifier = SecureRandom.urlsafe_base64(48)
      challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
      state = SecureRandom.urlsafe_base64(32)
      nonce = SecureRandom.urlsafe_base64(32)

      session[:oidc_code_verifier] = verifier
      session[:oidc_state] = state
      session[:oidc_nonce] = nonce
      session[:oidc_return_to] = safe_return_to(return_to)

      oidc_authorization_url(screen_hint: screen_hint, code_challenge: challenge, state: state, nonce: nonce)
    end

    def oidc_authorization_url(screen_hint:, code_challenge:, state:, nonce:)
      uri = URI::Generic.build(
        scheme: request.ssl? ? "https" : "http",
        host: oidc_sign_host,
        port: oidc_port,
        path: "/oauth/authorize",
      )
      query = {
        response_type: "code",
        client_id: oidc_client_id,
        redirect_uri: oidc_callback_url,
        code_challenge: code_challenge,
        code_challenge_method: "S256",
        state: state,
        nonce: nonce,
        scope: "openid profile",
      }
      query[:screen_hint] = screen_hint if screen_hint.present?
      uri.query = query.to_query
      uri.to_s
    end

    def oidc_callback_url
      Oidc::ClientRegistry.find!(oidc_client_id).redirect_uris.first
    end

    def oidc_token_url
      uri = URI::Generic.build(
        scheme: request.ssl? ? "https" : "http",
        host: oidc_sign_host,
        port: oidc_port,
        path: "/oauth/token",
      )
      uri.to_s
    end

    def oidc_port
      [80, 443].include?(request.port) ? nil : request.port
    end

    def encoded_return_to(return_to)
      Base64.urlsafe_encode64(return_to.to_s)
    end

    def decode_return_to(return_to)
      Base64.urlsafe_decode64(return_to.to_s)
    rescue ArgumentError
      "/"
    end

    def safe_return_to(return_to)
      uri = URI.parse(return_to.to_s)
      return "/" if uri.host.present? && uri.host != request.host

      uri.to_s.presence || "/"
    rescue URI::InvalidURIError
      "/"
    end

    def oidc_client_id
      raise NotImplementedError, "controller must define oidc_client_id"
    end

    def oidc_sign_host
      raise NotImplementedError, "controller must define oidc_sign_host"
    end
  end
end
