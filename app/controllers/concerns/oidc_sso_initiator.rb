# typed: false
# frozen_string_literal: true

module OidcSsoInitiator
  extend ActiveSupport::Concern
  include CommonRedirect

  def authenticate!
    if logged_in?
      SignRiskEnforcer.call(current_resource)
      return
    end

    return render(json: { error: "Unauthorized" }, status: :unauthorized) if request.format.json?

    SignRiskEmitter.emit(
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

  def initiate_oidc_session!(pt: "/", screen_hint: nil)
    verifier = SecureRandom.urlsafe_base64(48)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    state = SecureRandom.urlsafe_base64(32)
    nonce = SecureRandom.urlsafe_base64(32)

    session[:oidc_code_verifier] = verifier
    session[:oidc_state] = state
    session[:oidc_nonce] = nonce
    session[:oidc_pt] = safe_oidc_pt(pt)

    oidc_authorization_url(
      screen_hint: screen_hint,
      code_challenge: challenge,
      state: state,
      nonce: nonce,
    )
  end

  def redirect_to_oidc_authorization_url(url, **)
    return redirect_to(url, allow_other_host: true, **) if same_site_oidc_authorization_url?(url)

    redirect_to_jump_url(url, preserve_query_keys: ["redirect_uri"], **)
  end

  def same_site_oidc_authorization_url?(url)
    uri = URI.parse(url.to_s)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    return false unless uri.is_a?(URI::HTTP)
    return false unless uri.path == "/oauth/authorize"
    return false unless CommonRedirect.normalize_host(uri.host) == CommonRedirect.normalize_host(oidc_acme_host)
    return false unless oidc_same_site_host?(request.host, uri.host)
    return false unless query["client_id"].to_s == oidc_client_id.to_s
    return false unless defined?(OidcClientRegistry)
    return false unless OidcClientRegistry.valid_redirect_uri?(query["client_id"], query["redirect_uri"])

    true
  rescue URI::InvalidURIError
    false
  end

  def oidc_same_site_host?(source_host, target_host)
    oidc_site_key(source_host) == oidc_site_key(target_host)
  end

  def oidc_site_key(host)
    normalized = CommonRedirect.normalize_host(host)
    return if normalized.blank?

    labels = normalized.split(".")
    return normalized if labels.one?

    labels.last(2).join(".")
  end

  def oidc_authorization_url(screen_hint:, code_challenge:, state:, nonce:)
    uri = URI::Generic.build(
      scheme: oidc_acme_scheme,
      host: oidc_acme_host,
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
    client = OidcClientRegistry.find!(oidc_client_id)
    client.redirect_uris.find { |uri| URI.parse(uri).host == request.host } || client.redirect_uris.first
  rescue URI::InvalidURIError
    client.redirect_uris.first
  end

  def oidc_token_url
    uri = URI::Generic.build(
      scheme: oidc_acme_scheme,
      host: oidc_acme_host,
      port: oidc_port,
      path: "/oauth/token",
    )
    uri.to_s
  end

  def oidc_port
    [80, 443].include?(request.port) ? nil : request.port
  end

  def oidc_acme_scheme
    return "http" if !request.ssl? && oidc_acme_host.to_s.end_with?(".localhost")

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
  # Mirrors the shape of CommonRedirect#safe_internal_path (path?query
  # only, no scheme / host / userinfo / control chars). Inlined here instead
  # of delegated because OidcSsoInitiator is included on acme application
  # controllers that already mix in CommonRedirect via other paths, and we
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

  def oidc_acme_host
    raise NotImplementedError, "controller must define oidc_acme_host"
  end
end
