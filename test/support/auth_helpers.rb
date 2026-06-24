# typed: false
# frozen_string_literal: true

require_relative "../../app/controllers/concerns/authentication_base"
require_relative "../../app/controllers/concerns/authentication_client"
require_relative "../../app/controllers/concerns/authentication_operator"

module AuthHelpers
  TEST_USER_HEADER = "X-TEST-CURRENT-USER"
  TEST_STAFF_HEADER = "X-TEST-CURRENT-STAFF"
  TEST_RESOURCE_HEADER = "X-TEST-CURRENT-RESOURCE"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"
  MODERN_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                      "AppleWebKit/537.36 (KHTML, like Gecko) " \
                      "Chrome/120.0.0.0 Safari/537.36" unless const_defined?(:MODERN_USER_AGENT)

  def host_headers(host = nil)
    host_value =
      host ||
      (respond_to?(:request, true) ? request&.host : nil) ||
      ENV["DEFAULT_URL_HOST"]

    headers = { "Client-Agent" => MODERN_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => MODERN_USER_AGENT,
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge(TEST_USER_HEADER => user.id.to_s)

    if user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"
      token =
        if session_public_id.present?
          ClientToken.find_by(public_id: session_public_id)
        else
          ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
        end
      token ||= ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    base
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge(TEST_STAFF_HEADER => staff.id.to_s)

    if staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"
      token =
        if session_public_id.present?
          OperatorToken.find_by(public_id: session_public_id)
        else
          OperatorToken.where(staff_id: staff.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
        end
      token ||= OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    base
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    VisitorTokenBindingMethod.ensure_defaults!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    base = host_headers(host).merge(headers).merge(TEST_RESOURCE_HEADER => visitor.id.to_s)

    if visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"
      token = VisitorToken.where(visitor_id: visitor.id).where(
        "discarded_at > ?",
        Time.current,
      ).order(created_at: :desc).first
      token ||= VisitorToken.create!(visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    base
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end

    ::AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service =
      if normalized.include?("acme")
        "ACME"
      elsif normalized.include?("base")
        "BASE"
      elsif normalized.include?("core")
        "CORE"
      else
        "SIGN"
      end
    surface =
      if service == "SIGN"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif service == "BASE"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end

    "surface:#{service}_#{surface}"
  end

  def set_access_cookie(token)
    cookies[::AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[::AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def satisfy_user_verification(user_token)
    cookies[ClientVerification.cookie_name] = "#{TEST_VERIFICATION_COOKIE_PREFIX}#{user_token.public_id}"
    mark_token_step_up_satisfied_for_test(user_token)
    true
  end

  def satisfy_staff_verification(staff_token)
    cookies[OperatorVerification.cookie_name] = "#{TEST_VERIFICATION_COOKIE_PREFIX}#{staff_token.public_id}"
    mark_token_step_up_satisfied_for_test(staff_token)
    true
  end

  def satisfy_visitor_verification(visitor_token)
    cookies[VisitorVerification.cookie_name] = "#{TEST_VERIFICATION_COOKIE_PREFIX}#{visitor_token.public_id}"
    mark_token_step_up_satisfied_for_test(visitor_token)
    true
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end

  alias_method :set_user_access_cookie, :set_access_cookie
  alias_method :set_staff_access_cookie, :set_access_cookie

  def extract_cookies_from_response
    raw_header = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines =
      case raw_header
      when Array
        raw_header
      when String
        raw_header.split("\n")
      else
        []
      end

    parsed = {}
    lines.each do |line|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      next if name.blank?

      parsed[name] = CGI.unescape(value.to_s)
    end

    parsed
  end

  def response_has_cookie?(name)
    raw_header = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines =
      case raw_header
      when Array
        raw_header
      when String
        raw_header.split("\n")
      else
        []
      end

    lines.any? { |line| line.start_with?("#{name}=") }
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include AuthHelpers
  include MissingHelpers if defined?(MissingHelpers)
end
