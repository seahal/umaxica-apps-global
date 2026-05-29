# typed: false
# frozen_string_literal: true

module Jump::ToRedirector
  extend ActiveSupport::Concern
  include Common::Redirect
  include ::Redirects::SignedTargetSupport

  JUMP_TARGET_TOKEN_SALT = "jump_target_token"
  JUMP_TARGET_TOKEN_PURPOSE = :jump_target
  JUMP_TARGET_TOKEN_EXPIRES_IN = 15.minutes

  included do
    skip_before_action :apply_localization_preferences, raise: false
    before_action :disable_cookie_session
  end

  def show
    return render_not_found if params[:jt].blank?

    destination = verified_jump_target(params[:jt])
    return render_not_found if destination.blank?

    response.set_header("Referrer-Policy", "no-referrer")

    Rails.logger.silence do
      redirect_to_external_jump_url(destination.fetch("url"), allowed_urls: [destination.fetch("url")])
    end
  end

  private

  def render_not_found
    render plain: I18n.t("jump.redirector.unavailable"), status: :not_found, content_type: "text/plain"
  end

  def disable_cookie_session
    request.session_options[:skip] = true
  end

  # Check if the URI's host is in the allowed list
  def allowed_jump_host?(uri)
    allowed_hosts.include?(normalized_destination_host(uri))
  end

  # Returns list of allowed hosts for jump redirects
  def allowed_hosts
    # Use JUMP_ALLOWED_HOSTS env var (comma-separated) or fallback to empty array
    hosts =
      ENV.fetch("JUMP_ALLOWED_HOSTS", "").split(",").filter_map do |value|
        normalize_allowed_host(value)
      end
    hosts.compact_blank
  end

  def normalize_allowed_host(value)
    raw = value.to_s.strip
    return if raw.blank?

    uri = URI.parse(raw.include?("://") ? raw : "https://#{raw}")
    return if uri.host.blank?

    normalized_destination_host(uri)
  rescue URI::InvalidURIError
    nil
  end

  def normalized_destination_host(uri)
    host = uri.host&.downcase
    return if host.blank?

    default_port =
      if uri.scheme == "https"
        443
      else
        80
      end
    return host if uri.port.blank? || uri.port == default_port

    "#{host}:#{uri.port}"
  end

  def issue_jump_target_token(url:, path:)
    destination = safe_jump_destination(url)
    signed_path = signed_target_internal_path(path)
    if destination.blank? || signed_path.blank? || destination.fetch("path") != signed_path
      log_signed_target_rejection("jump_target.rejected", "blank_jump_target")
      return nil
    end

    claims = signed_target_claims(
      flow: jump_target_flow,
      surface: jump_target_surface,
      session_nonce: jump_target_session_nonce,
    )
    if claims.blank?
      log_signed_target_rejection("jump_target.rejected", "blank_common_claim")
      return nil
    end

    issue_signed_target_token(
      payload: claims.merge("url" => destination.fetch("url"), "path" => signed_path),
      purpose: JUMP_TARGET_TOKEN_PURPOSE,
      salt: JUMP_TARGET_TOKEN_SALT,
      expires_in: JUMP_TARGET_TOKEN_EXPIRES_IN,
    )
  end

  def verified_jump_target(token)
    payload = verified_signed_target_payload(
      token,
      purpose: JUMP_TARGET_TOKEN_PURPOSE,
      salt: JUMP_TARGET_TOKEN_SALT,
      expected_flow: jump_target_flow,
      expected_surface: jump_target_surface,
      session_nonce: jump_target_session_nonce,
    )
    return nil if payload.blank?

    destination = safe_jump_destination(payload["url"])
    signed_path = signed_target_internal_path(payload["path"])
    return nil if destination.blank? || signed_path.blank?
    return nil unless destination.fetch("path") == signed_path

    destination.slice("url", "path")
  end

  def safe_jump_destination(url)
    value = signed_target_clean_string(url)
    return nil if value.blank?

    uri = URI.parse(value)
    return nil unless %w(http https).include?(uri.scheme&.downcase)
    return nil if uri.host.blank?
    return nil if uri.userinfo.present?
    return nil if uri.fragment.present?
    return nil unless allowed_jump_host?(uri)

    path = uri.path.presence || "/"
    return nil unless path.start_with?("/")
    return nil if path.start_with?("//")

    query = uri.query.present? ? "?#{uri.query}" : ""
    port = (uri.port && uri.port != default_port_for(uri.scheme)) ? ":#{uri.port}" : ""
    {
      "url" => "#{uri.scheme.downcase}://#{uri.host.downcase}#{port}#{path}#{query}",
      "path" => "#{path}#{query}",
    }
  rescue URI::InvalidURIError
    nil
  end

  def jump_target_flow
    "jump"
  end

  def jump_target_surface
    case self.class.name
    when /::App::/ then "app"
    when /::Com::/ then "com"
    when /::Org::/ then "org"
    else
      "jump"
    end
  end

  def jump_target_session_nonce
    "jump"
  end

  def default_port_for(scheme)
    scheme.to_s.casecmp("https").zero? ? 443 : 80
  end
end
