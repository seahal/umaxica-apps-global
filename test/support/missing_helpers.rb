# typed: false
# frozen_string_literal: true

require "openssl"
require "jwt"
require "base64"
require "sha3"

ENV["ID_SERVICE_URL"] ||= "id.umaxica.app"
ENV["SIGN_SERVICE_URL"] ||= "id.umaxica.app"
ENV["ID_STAFF_URL"] ||= "id.umaxica.org"
ENV["SIGN_STAFF_URL"] ||= "id.umaxica.org"
ENV["ID_CORPORATE_URL"] ||= "id.umaxica.com"
ENV["SIGN_CORPORATE_URL"] ||= "id.umaxica.com"

ENV["EMAIL_ADDRESS_HMAC_SALT"] ||= "test-email-address-secret_credential"
ENV["TELEPHONE_NUMBER_HMAC_SALT"] ||= "test-telephone-number-secret_credential"
ENV["PROMOTIONAL_UNSUBSCRIBE_HMAC_SALT"] ||= "test-promotional-unsubscribe-secret_credential"

class SocialAuthTestCsrfController < (defined?(ApplicationController) ? ApplicationController : ActionController::Base)
  protect_from_forgery using: :header_or_legacy_token

  def show
    render plain: form_authenticity_token
  end

  def create
    head :ok
  end
end

module PreferenceJwtHelper
  def self.fixed_test_key
    @fixed_test_key ||= OpenSSL::PKey::EC.generate("secp384r1")
  end

  def encode_preference_jwt(preferences:, host:, public_id:, preference_type: "AppPreference")
    jti = "test-jti-#{SecureRandom.uuid}"

    with_preference_jwt_keys(host: host) do
      Preference::Token.encode(
        preferences,
        host: host,
        preference_type: preference_type,
        public_id: public_id,
        jti: jti,
      )
    end
  end

  def with_preference_jwt_keys(host:)
    key = PreferenceJwtHelper.fixed_test_key
    audiences = host ? [host] : Preference::JwtConfiguration.audiences

    Preference::JwtConfiguration.stub(:private_key, key) do
      Preference::JwtConfiguration.stub(:public_key, key) do
        Preference::JwtConfiguration.stub(:private_key_for_active, key) do
          Preference::JwtConfiguration.stub(:public_key_for, ->(_kid, **_options) { key }) do
            Preference::JwtConfiguration.stub(:active_kid, "default") do
              Preference::JwtConfiguration.stub(:issuer, "jit-preference") do
                Preference::JwtConfiguration.stub(:audiences, audiences) do
                  yield
                end
              end
            end
          end
        end
      end
    end
  end
end

module MissingHelpers
  include PreferenceJwtHelper

  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  def as_user_headers(user, host:, headers: {}, session_public_id: nil)
    authenticated_headers_for(user, host: host, headers: headers, session_public_id: session_public_id)
  end

  def as_staff_headers(staff, host:, headers: {}, session_public_id: nil)
    authenticated_headers_for(staff, host: host, headers: headers, session_public_id: session_public_id)
  end

  def as_visitor_headers(visitor, host:, headers: {}, session_public_id: nil)
    authenticated_headers_for(visitor, host: host, headers: headers, session_public_id: session_public_id)
  end

  def authenticated_headers_for(resource, host:, headers: {}, session_public_id: nil)
    token_record = create_auth_token_record_for(resource, session_public_id: session_public_id)
    access_token = Authentication::TokenService.encode(
      resource,
      host: host,
      session_public_id: token_record.public_id,
      resource_type: auth_resource_type_for(resource),
      expires_at: 1.hour.from_now,
      acr: "aal1",
      amr: ["test"],
      jwt_issuer_id: jwt_issuer_id_for_test_host(host, auth_resource_type_for(resource)),
    )

    {
      "Host" => host,
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => token_record.public_id,
    }.merge(headers)
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service =
      if normalized.include?("acme")
        "ACME"
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
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end

    "surface:#{service}_#{surface}"
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    @signed_step_up_pt_cache ||= {}
    cache_key = [path.to_s, surface.to_s, session_nonce.to_s]
    return @signed_step_up_pt_cache[cache_key] if @signed_step_up_pt_cache.key?(cache_key)

    safe_path = path.to_s
    return nil if safe_path.blank?
    return nil unless safe_path.start_with?("/")
    return nil if safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier =
      ActiveSupport::MessageVerifier.new(
        Rails.application.key_generator.generate_key("path_target_token", 32),
        digest: "SHA256",
        serializer: JSON,
        url_safe: true,
      )

    @signed_step_up_pt_cache[cache_key] = verifier.generate(
      {
        "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path,
      },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def browser_headers
    {
      "Client-Agent" => "Mozilla/5.0 (Test Browser)",
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    }
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    env = {
      "JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-test",
      "JWT_SIGN_APP_PRIVATE_KEY" => jump_rt_key,
      "JWT_SIGN_ORG_ACTIVE_KID" => "sign-org-test",
      "JWT_SIGN_ORG_PRIVATE_KEY" => jump_rt_key,
      "JWT_SIGN_COM_ACTIVE_KID" => "sign-com-test",
      "JWT_SIGN_COM_PRIVATE_KEY" => jump_rt_key,
      "JWT_ACME_APP_ACTIVE_KID" => "acme-app-test",
      "JWT_ACME_APP_PRIVATE_KEY" => jump_rt_key,
      "JWT_ACME_ORG_ACTIVE_KID" => "acme-org-test",
      "JWT_ACME_ORG_PRIVATE_KEY" => jump_rt_key,
      "JWT_ACME_COM_ACTIVE_KID" => "acme-com-test",
      "JWT_ACME_COM_PRIVATE_KEY" => jump_rt_key,
      "JWT_CORE_APP_ACTIVE_KID" => "core-app-test",
      "JWT_CORE_APP_PRIVATE_KEY" => jump_rt_key,
      "JWT_CORE_ORG_ACTIVE_KID" => "core-org-test",
      "JWT_CORE_ORG_PRIVATE_KEY" => jump_rt_key,
      "JWT_CORE_COM_ACTIVE_KID" => "core-com-test",
      "JWT_CORE_COM_PRIVATE_KEY" => jump_rt_key,
    }

    env.each do |key, value|
      @jump_rt_env_originals[key] = ENV[key] unless @jump_rt_env_originals.key?(key)
      ENV[key] = value
    end
    Jit::Security::Jwt::Registry.reload! if defined?(Jit::Security::Jwt::Registry)
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def host_headers(host)
    { "Host" => host }
  end

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  def fetch_csrf_token(path)
    get(path)
    if response.body.include?('name="authenticity_token"')
      response.body.match(/name="authenticity_token" value="([^"]+)"/)[1]
    else
      response.body
    end
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def social_callback_headers(host)
    scheme = host.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence ||
      begin
        uri = URI.parse(response.location.to_s)
        Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
      rescue URI::InvalidURIError
        nil
      end
  end

  def seed_social_auth_session(provider:, intent: "login", user: nil, entry: nil, ri: "jp", rt: nil)
    host = ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app")
    host!(host) if respond_to?(:host!)
    https! if respond_to?(:https!) && host.exclude?("localhost")
    continue_path = continue_sign_app_social_authentication_path(
      provider: provider,
      intent: intent,
      ri: ri,
      entry: entry,
      rt: rt,
    )

    with_social_auth_csrf_route do |csrf_path|
      csrf_token = fetch_csrf_token(csrf_path)
      headers = social_callback_headers(host).merge(csrf_headers(csrf_token))
      if user
        user_headers = as_user_headers(user, host: host)
        if intent.to_s == "link"
          token = ClientToken.find_by(public_id: user_headers["X-TEST-SESSION-PUBLIC-ID"])
          mark_token_step_up_satisfied_for_test(token, scope: SocialAuthConcern::SOCIAL_LINK_SCOPE) if token
        end
        headers = headers.merge(user_headers)
      end

      post(
        continue_path,
        headers: headers,
      )

      assert_response :redirect
      social_auth_state_from_response
    end
  end

  def with_social_auth_csrf_route
    Rails.application.routes.append do
      get("/test_social_auth_csrf", to: "social_auth_test_csrf#show")
      post("/test_social_auth_csrf", to: "social_auth_test_csrf#create")
    end

    yield "/test_social_auth_csrf"
  ensure
    Rails.application.reload_routes!
  end

  def response_has_cookie?(name)
    cookie_lines = response_set_cookie_lines
    cookie_lines.any? { |line| line.start_with?("#{name}=") }
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

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines =
      case raw
      when Array then raw
      when String then raw.split("\n")
      else []
      end

    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, cookies|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      cookies[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def response_cookie_expiry(name)
    cookie_str = response_set_cookie_lines.find { |c| c.start_with?("#{name}=") }
    return nil unless cookie_str

    match = cookie_str.match(/expires=([^;]+)/i)
    return nil unless match

    Time.zone.parse(match[1])
  end

  def assert_theme_cookie_for(host:, path:, label:, ri:)
    get(public_send(path, ri: ri), headers: { "Host" => host })

    assert_response :success, "expected #{label} to render successfully"
    assert response_has_cookie?(Preference::IoKeys::Cookies::THEME),
           "expected #{label} to set the theme cookie"
  end

  def assert_layout_contract
    assert_select "html"
    assert_select "body"
    assert_select "header"
    assert_select "main"
    assert_select "footer"
    assert_select "span.bg-black.text-white", text: "SIGN"
  end

  def extract_verification_challenge_id
    match =
      response.body.match(/name="verification\[challenge_id\]" value="([^"]+)"/) ||
      response.body.match(/data-step-up-passkey-challenge-id-value="([^"]+)"/)
    match&.[](1)
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      {
        provider: "google_app",
        uid: uid,
        info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      },
    )
  end

  def setup_apple_mock_auth(uid: "apple_uid_123", email: "apple@example.com")
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: uid,
        info: { email: email },
        credentials: { token: "apple_token", expires_at: 1.hour.from_now.to_i },
      },
    )
  end

  def ensure_auth_reference_rows!(mapping)
    mapping.each do |klass, id|
      klass.find_or_create_by!(id: id)
    end
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    if defined?(VisitorSecretCredentialStatus)
      VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::ACTIVE)
      VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::EXPIRED)
      VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::REVOKED)
      VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::USED)
      VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::DELETED)
      VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::NOTHING)
    end
    if defined?(VisitorSecretCredentialKind)
      VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::LOGIN)
      VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::RECOVERY)
      VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::API)
    end
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!

    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.refresh_mfa_status! if user.respond_to?(:refresh_mfa_status!)
    user.reload
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!

    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    insert_verified_visitor_email!(visitor_id: visitor.id, address: email_address)
    visitor.refresh_mfa_status! if visitor.respond_to?(:refresh_mfa_status!)
    visitor.reload
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    verification_scope = scope.presence || token.last_step_up_scope.presence || "verification"
    attrs = {
      last_step_up_at: Time.current,
      last_step_up_scope: verification_scope,
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    verification_scope = scope.presence || token.last_step_up_scope.presence || "verification"
    attrs = {
      last_step_up_at: Time.current,
      last_step_up_scope: verification_scope,
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end

  def satisfy_visitor_verification(visitor_token)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: visitor_token)
    cookies[VisitorVerification.cookie_name] = raw_token
    true
  end

  private

  def create_auth_token_record_for(resource, session_public_id: nil)
    operation =
      lambda do
        token_class = auth_token_class_for(resource)

        if session_public_id.present?
          existing = token_class.find_by(public_id: session_public_id)
          if existing.present? && auth_token_matches_resource?(existing, resource)
            return existing
          end
        end

        if instance_variable_defined?(:@token)
          existing = instance_variable_get(:@token)
          return existing if auth_token_matches_resource?(existing, resource)
        end

        revoke_existing_auth_tokens_for(resource, token_class)
        attrs = auth_token_attributes_for(resource)
        attrs[:public_id] = session_public_id if session_public_id.present?
        token = token_class.new(attrs)
        token.skip_session_limit_check = true if token.respond_to?(:skip_session_limit_check=)
        token.created_at = 2.minutes.ago if token.respond_to?(:created_at=)
        token.save!
        @token = token
        token
      end

    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  def revoke_existing_auth_tokens_for(resource, token_class)
    foreign_key =
      case resource
      when Client then :user_id
      when Operator then :staff_id
      when Visitor then :visitor_id
      end

    token_class.where(foreign_key => resource.id).find_each do |token|
      next unless token.respond_to?(:revoke!) && !token.revoked?

      if defined?(Prosopite)
        Prosopite.pause { token.revoke! }
      else
        token.revoke!
      end
    end
  end

  def auth_token_attributes_for(resource)
    case resource
    when Client
      ensure_auth_reference_rows!(
        ClientTokenKind => ClientTokenKind::BROWSER_WEB,
        ClientTokenStatus => ClientTokenStatus::ACTIVE,
        ClientTokenBindingMethod => ClientTokenBindingMethod::LEGACY,
        ClientTokenDbscStatus => ClientTokenDbscStatus::NOTHING,
      )
      {
        user_id: resource.id,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE,
        user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
        user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
      }
    when Operator
      ensure_auth_reference_rows!(
        OperatorTokenKind => OperatorTokenKind::BROWSER_WEB,
        OperatorTokenStatus => OperatorTokenStatus::ACTIVE,
        OperatorTokenBindingMethod => OperatorTokenBindingMethod::LEGACY,
        OperatorTokenDbscStatus => OperatorTokenDbscStatus::NOTHING,
      )
      {
        staff_id: resource.id,
        staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
        staff_token_status_id: OperatorTokenStatus::ACTIVE,
        staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
        staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
      }
    when Visitor
      ensure_auth_reference_rows!(
        VisitorTokenKind => VisitorTokenKind::BROWSER_WEB,
        VisitorTokenStatus => VisitorTokenStatus::ACTIVE,
        VisitorTokenBindingMethod => VisitorTokenBindingMethod::LEGACY,
        VisitorTokenDbscStatus => VisitorTokenDbscStatus::NOTHING,
      )
      {
        visitor_id: resource.id,
        visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
        visitor_token_status_id: VisitorTokenStatus::ACTIVE,
        visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
        visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
      }
    else
      raise ArgumentError, "unsupported authenticated test resource: #{resource.class.name}"
    end
  end

  def auth_token_class_for(resource)
    case resource
    when Client then ClientToken
    when Operator then OperatorToken
    when Visitor then VisitorToken
    else
      raise ArgumentError, "unsupported authenticated test resource: #{resource.class.name}"
    end
  end

  def auth_token_matches_resource?(token, resource)
    case resource
    when Client
      token.respond_to?(:user_id) && token.user_id == resource.id
    when Operator
      token.respond_to?(:staff_id) && token.staff_id == resource.id
    when Visitor
      token.respond_to?(:visitor_id) && token.visitor_id == resource.id
    else
      false
    end
  end

  def auth_resource_type_for(resource)
    case resource
    when Client then "client"
    when Operator then "operator"
    when Visitor then "visitor"
    else
      raise ArgumentError, "unsupported authenticated test resource: #{resource.class.name}"
    end
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def build_occurrence(klass, attrs = {})
    klass.new(attrs)
  end

  def assert_invalid_attribute(record, attribute)
    assert_not_predicate record, :valid?, "expected #{record.class.name} to be invalid"
    assert_includes record.errors.attribute_names, attribute
  end

  def assert_public_id_generated(record)
    assert_predicate record, :valid?
    assert_predicate record.public_id, :present?
    assert_equal 21, record.public_id.length
  end

  def assert_public_id_preserved(record, expected_public_id)
    assert_predicate record, :valid?
    assert_equal expected_public_id, record.public_id
  end

  def assert_occurrence_lifecycle_defaults(record)
    assert_equal Float::INFINITY, record.discarded_at
    assert_equal Float::INFINITY, record.purged_at
  end

  def assert_status_association(status_class, association_name)
    reflection = status_class.reflect_on_association(association_name)

    assert_not_nil reflection
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.insert_all(
      [{
        user_id: user_id,
        address: address,
        address_digest: IdentifierBlindIndex.bidx_for_email(address),
        user_email_status_id: ClientEmailStatus::VERIFIED,
        otp_private_key: SecureRandom.base64(24),
        otp_counter: "",
        otp_attempts_count: 0,
        public_id: SecureRandom.alphanumeric(21),
        created_at: Time.current,
        updated_at: Time.current,
      }],
    )
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [{
        visitor_id: visitor_id,
        address: address,
        address_digest: IdentifierBlindIndex.bidx_for_email(address),
        visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        otp_private_key: SecureRandom.base64(24),
        otp_counter: "",
        otp_attempts_count: 0,
        public_id: SecureRandom.alphanumeric(21),
        created_at: Time.current,
        updated_at: Time.current,
      }],
    )
  end
end

module SocialCallbackTestHelper
  def self.callback_headers(host)
    scheme = host.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "X-STRICT-SOCIAL-STATE" => "1",
    }
  end
end

module SocialCallbackGuardTestHelpers
  private

  def test_mode_mock_auth_present?
    return false unless defined?(OmniAuth) && OmniAuth.config.respond_to?(:test_mode) && OmniAuth.config.test_mode

    provider = params[:provider].to_s
    return false if provider.blank?

    auth = OmniAuth.config.mock_auth[provider.to_sym] || OmniAuth.config.mock_auth[provider]
    auth.present?
  end
end

SocialCallbackGuard.prepend(SocialCallbackGuardTestHelpers) if defined?(SocialCallbackGuard)

if defined?(Sign::Org::Auth::OmniauthCallbacksController)
  class Sign::Org::Auth::OmniauthCallbacksController
    private

    def mock_auth_from_test_mode
      provider = params[:provider].to_s
      OmniAuth.config.mock_auth[provider.to_sym] || OmniAuth.config.mock_auth[provider]
    end
  end
end

module AuthHelpers
  MODERN_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" unless const_defined?(:MODERN_USER_AGENT)
end

module CommitteeHelper
  def assert_response_schema_confirm(*)
  end
end

module AuthenticationBaseTestSupport
  def current_resource
    test_resource = test_current_resource_from_headers
    return @current_resource = test_resource if test_resource.present?

    super
  end

  def current_session_public_id
    test_session_public_id = test_current_session_public_id_from_headers
    return test_session_public_id if test_session_public_id.present?

    super
  end

  def bulletin_state
    maybe_inject_test_bulletin!
    super
  end

  def maybe_inject_test_bulletin!
    header_key = Auth::IoKeys::Headers::TEST_BULLETIN
    raw = request.headers[header_key].presence
    return if raw.blank?

    bulletin = JSON.parse(raw)
    session[Authentication::Base::BULLETIN_SESSION_KEY] = bulletin if bulletin.is_a?(Hash)
  rescue JSON::ParserError, TypeError
    nil
  end

  private

  def test_current_resource_from_headers
    headers = respond_to?(:request, true) ? request&.headers : nil
    return nil unless headers

    header_keys = Array(test_header_keys)
    header = header_keys.filter_map { |key| headers[key] }.find(&:present?)
    return nil if header.blank?

    resource_class.find_by(id: header.to_s)
  rescue StandardError
    nil
  end

  def test_current_session_public_id_from_headers
    headers = respond_to?(:request, true) ? request&.headers : nil
    headers&.[]("X-TEST-SESSION-PUBLIC-ID").to_s.presence
  end

  def test_header_key
    test_header_keys.first
  end

  def test_header_keys
    case resource_type.to_s.downcase
    when "client", "user"
      ["X-TEST-CURRENT-USER"]
    when "operator", "staff"
      ["X-TEST-CURRENT-STAFF"]
    when "visitor", "viewer"
      ["X-TEST-CURRENT-VIEWER", "X-TEST-CURRENT-RESOURCE"]
    else
      ["X-TEST-CURRENT-RESOURCE"]
    end
  end
end

Authentication::Base.prepend(AuthenticationBaseTestSupport)

unless Auth::IoKeys::Headers.const_defined?(:TEST_BULLETIN)
  Auth::IoKeys::Headers.const_set(:TEST_BULLETIN, "X-TEST-BULLETIN")
end

if defined?(ActiveSupport::TestCase)
  if defined?(CloudflareTurnstile)
    class << CloudflareTurnstile
      alias_method :test_mode, :validation_override_enabled
      alias_method :test_mode=, :validation_override_enabled=
      alias_method :test_validation_response, :validation_override_response
      alias_method :test_validation_response=, :validation_override_response=
    end
  end

  if defined?(Turnstile)
    class << Turnstile
      alias_method :test_response, :validation_override_response
      alias_method :test_response=, :validation_override_response=
    end
  end

  ActiveSupport::TestCase.setup do
    RateLimit.store.clear if defined?(RateLimit)
    Authentication::Base.login_cooldown_enabled = false if defined?(Authentication::Base)
    [
      ClientTokenBindingMethod,
      ClientTokenDbscStatus,
      ClientTokenKind,
      ClientTokenStatus,
    ].each do |model|
      model.ensure_defaults! if model.respond_to?(:ensure_defaults!)
    end
  end

  ActiveSupport::TestCase.teardown do
    RateLimit.store.clear if defined?(RateLimit)
    Authentication::Base.login_cooldown_enabled = false if defined?(Authentication::Base)
  end

  class << ActiveSupport::TestCase
    def fixtures_none!
      self.fixture_table_names = []
    end

    def fixtures_only(*fixture_names)
      self.fixture_table_names = fixture_names.flatten.map(&:to_s)
    end
  end
end
