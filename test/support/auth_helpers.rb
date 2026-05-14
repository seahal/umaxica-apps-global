# typed: false
# frozen_string_literal: true

require_relative "../../app/controllers/concerns/authentication/base"
require_relative "../../app/controllers/concerns/authentication/user"
require_relative "../../app/controllers/concerns/authentication/operator"

module AuthHelpers
  TEST_USER_HEADER = "X-TEST-CURRENT-USER"
  TEST_STAFF_HEADER = "X-TEST-CURRENT-STAFF"
  TEST_RESOURCE_HEADER = "X-TEST-CURRENT-RESOURCE"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"
  MODERN_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                      "AppleWebKit/537.36 (KHTML, like Gecko) " \
                      "Chrome/120.0.0.0 Safari/537.36"

  def host_headers(host = nil)
    host_value =
      host ||
      (respond_to?(:request, true) ? request&.host : nil) ||
      ENV["DEFAULT_URL_HOST"]

    headers = { "User-Agent" => MODERN_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "User-Agent" => MODERN_USER_AGENT,
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def as_user_headers(user, host: nil, headers: {})
    base = host_headers(host).merge(headers).merge(TEST_USER_HEADER => user.id.to_s)

    if user.respond_to?(:persisted?) && user.persisted? && user.class.name == "User"
      token = UserToken.where(user_id: user.id).where("lapses_at > ?", Time.current).order(created_at: :desc).first
      token ||= UserToken.create!(user_id: user.id, user_token_kind_id: UserTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = token.public_id
    end

    base
  end

  def as_staff_headers(staff, host: nil, headers: {})
    host_headers(host).merge(headers).merge(TEST_STAFF_HEADER => staff.id.to_s)
  end

  def as_visitor_headers(visitor, host: nil, headers: {})
    VisitorTokenBindingMethod.ensure_defaults!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    base = host_headers(host).merge(headers).merge(TEST_RESOURCE_HEADER => visitor.id.to_s)

    if visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"
      token = VisitorToken.where(visitor_id: visitor.id).where(
        "lapses_at > ?",
        Time.current,
      ).order(created_at: :desc).first
      token ||= VisitorToken.create!(visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = token.public_id
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
      when User then "user"
      when Operator then "operator"
      when Visitor then "visitor"
      end

    ::Authentication::Base::Token.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
    )
  end

  def set_access_cookie(token)
    cookies[::Authentication::Base::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[::Authentication::Base::REFRESH_COOKIE_KEY] = token
  end

  def satisfy_user_verification(user_token)
    cookies[UserVerification.cookie_name] = "#{TEST_VERIFICATION_COOKIE_PREFIX}#{user_token.public_id}"
    true
  end

  def satisfy_staff_verification(staff_token)
    cookies[OperatorVerification.cookie_name] = "#{TEST_VERIFICATION_COOKIE_PREFIX}#{staff_token.public_id}"
    true
  end

  def satisfy_visitor_verification(visitor_token)
    cookies[VisitorVerification.cookie_name] = "#{TEST_VERIFICATION_COOKIE_PREFIX}#{visitor_token.public_id}"
    true
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

ActiveSupport.on_load(:action_dispatch_integration_test) { include AuthHelpers }
