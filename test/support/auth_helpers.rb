# typed: false
# frozen_string_literal: true

require_relative "../../app/controllers/concerns/authentication/base"
require_relative "../../app/controllers/concerns/authentication/user"
require_relative "../../app/controllers/concerns/authentication/staff"

module AuthHelpers
  TEST_USER_HEADER = "X-TEST-CURRENT-USER"
  TEST_STAFF_HEADER = "X-TEST-CURRENT-STAFF"
  TEST_RESOURCE_HEADER = "X-TEST-CURRENT-RESOURCE"
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

  def as_customer_headers(customer, host: nil, headers: {})
    CustomerTokenBindingMethod.ensure_defaults!
    CustomerTokenKind.find_or_create_by!(id: CustomerTokenKind::BROWSER_WEB)
    base = host_headers(host).merge(headers).merge(TEST_RESOURCE_HEADER => customer.id.to_s)

    if customer.respond_to?(:persisted?) && customer.persisted? && customer.class.name == "Customer"
      token = CustomerToken.where(customer_id: customer.id).where(
        "lapses_at > ?",
        Time.current,
      ).order(created_at: :desc).first
      token ||= CustomerToken.create!(customer_id: customer.id, customer_token_kind_id: CustomerTokenKind::BROWSER_WEB)
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
      when Staff then "staff"
      when Customer then "customer"
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
    verification, raw_token = UserVerification.issue_for_token!(token: user_token)
    cookies[UserVerification.cookie_name] = raw_token
    verification
  end

  def satisfy_staff_verification(staff_token)
    verification, raw_token = StaffVerification.issue_for_token!(token: staff_token)
    cookies[StaffVerification.cookie_name] = raw_token
    verification
  end

  def satisfy_customer_verification(customer_token)
    verification, raw_token = CustomerVerification.issue_for_token!(token: customer_token)
    cookies[CustomerVerification.cookie_name] = raw_token
    verification
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
