# typed: false
# frozen_string_literal: true

module Oidc
  module SsoInitiator
    extend ActiveSupport::Concern
    include Common::Redirect

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
      url = sign_in_url_with_pt(encoded_pt(request.original_url))
      redirect_to_oidc_authorization_url(url)
    end

    def sign_in_url_with_pt(pt)
      initiate_oidc_session!(pt: decode_pt(pt))
    end

    private

    def initiate_oidc_session!(pt: request.original_url, screen_hint: nil)
      verifier = SecureRandom.urlsafe_base64(48)
      challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
      state = SecureRandom.urlsafe_base64(32)
      nonce = SecureRandom.urlsafe_base64(32)

      session[:oidc_code_verifier] = verifier
      session[:oidc_state] = state
      session[:oidc_nonce] = nonce
      session[:oidc_pt] = safe_oidc_pt(pt)

      oidc_authorization_url(screen_hint: screen_hint, code_challenge: challenge, state: state, nonce: nonce)
    end

    def redirect_to_oidc_authorization_url(url, **)
      redirect_to_jump_url(url, preserve_query_keys: oidc_authorization_preserve_query_keys(url), **)
    end

    def oidc_authorization_url(screen_hint:, code_challenge:, state:, nonce:)
      uri = URI::Generic.build(
        scheme: oidc_sign_scheme,
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

    def oidc_authorization_preserve_query_keys(url)
      uri = URI.parse(url.to_s)
      query = Rack::Utils.parse_nested_query(uri.query.to_s)
      return [] unless uri.is_a?(URI::HTTP)
      return [] unless uri.host == oidc_sign_host
      return [] unless uri.path == "/oauth/authorize"
      return [] unless query["client_id"] == oidc_client_id
      return [] unless query["redirect_uri"] == oidc_callback_url

      ["redirect_uri"]
    rescue URI::InvalidURIError
      []
    end

    def oidc_callback_url
      Oidc::ClientRegistry.find!(oidc_client_id).redirect_uris.first
    end

    def oidc_token_url
      uri = URI::Generic.build(
        scheme: oidc_sign_scheme,
        host: oidc_sign_host,
        port: oidc_port,
        path: "/oauth/token",
      )
      uri.to_s
    end

    def oidc_port
      [80, 443].include?(request.port) ? nil : request.port
    end

    def oidc_sign_scheme
      return "http" if !request.ssl? && oidc_sign_host.to_s.end_with?(".localhost")

      "https"
    end

    def encoded_pt(pt)
      Base64.urlsafe_encode64(pt.to_s)
    end

    def decode_pt(pt)
      Base64.urlsafe_decode64(pt.to_s)
    rescue ArgumentError
      "/"
    end

    # Tighten the OIDC pt to a same-host internal path.
    #
    # Mirrors the shape of Common::Redirect#safe_internal_path (path?query
    # only, no scheme / host / userinfo / control chars). Inlined here instead
    # of delegated because Oidc::SsoInitiator is included on acme application
    # controllers that already mix in Common::Redirect via other paths, and we
    # want this validator to be self-contained while the broader unification
    # is planned separately. Future work: share the helper.
    def safe_oidc_pt(pt)
      target = pt.to_s
      return "/" if target.blank?
      return "/" if target.match?(/[[:cntrl:]]/)

      begin
        uri = URI.parse(target)
      rescue URI::InvalidURIError
        return "/"
      end

      return "/" if uri.user.present? || uri.password.present?

      if uri.scheme.present? || uri.host.present?
        scheme_ok = %w(http https).include?(uri.scheme)
        host_ok = uri.host.present? && uri.host == request.host
        return "/" unless scheme_ok && host_ok
      end

      path = uri.path.presence || "/"
      return "/" unless path.start_with?("/")

      uri.query.present? ? "#{path}?#{uri.query}" : path
    end

    def oidc_client_id
      raise NotImplementedError, "controller must define oidc_client_id"
    end

    def oidc_sign_host
      raise NotImplementedError, "controller must define oidc_sign_host"
    end
  end
end
