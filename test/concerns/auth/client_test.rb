# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthClientTest < ActiveSupport::TestCase
  fixtures :client_statuses

  class FormatMock
    attr_accessor :format_type

    def initialize(format_type = :html)
      @format_type = format_type
    end

    def json?
      @format_type == :json
    end
  end

  class DummyClass
    include SessionLimitGate
    include AuthenticationClient

    attr_accessor :session, :cookies, :request, :response

    def initialize
      @session = {}
      @cookies = CookieMock.new
      @response = ResponseMock.new
      format = FormatMock.new
      @request = OpenStruct.new(host: "id.app.localhost", headers: {}, user_agent: "TestAgent", format: format)
    end

    def reset_session
      @session = {}
    end

    def controller_path
      "auth/clients"
    end

    def sign_org_edge_v0_token_dbsc_path
      "/edge/v0/token/dbsc"
    end

    def sign_app_edge_v0_token_dbsc_path
      "/edge/v0/token/dbsc"
    end
  end

  class ResponseMock
    def set_header(_name, _value) end
  end

  class CookieMock < Hash
    attr_reader :options

    def initialize
      super
      @options = {}
    end

    def encrypted
      self
    end

    def []=(key, value)
      if value.is_a?(Hash) && value.key?(:value)
        opts = value.dup
        actual_value = opts.delete(:value)
        super(key, actual_value)
        @options[key] = opts
      else
        super(key, value)
      end
    end

    def delete(key, _options = {})
      super(key)
    end

    def options_for(key)
      @options[key]
    end
  end

  setup do
    @obj = DummyClass.new
    @user = Client.create!(status_id: ClientStatus::NOTHING, public_id: SecureRandom.alphanumeric(21))
    ClientToken.where(user_id: @user.id).delete_all
  end

  test "module can be included" do
    assert_kind_of AuthenticationClient, @obj
  end

  test "log_in sets access token in cookie" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @user)

    assert @obj.cookies[::AuthenticationClient::ACCESS_COOKIE_KEY]
    assert_predicate @obj, :logged_in?
    assert_equal @user, @obj.current_client
  end

  test "log_in sets cookie expirations" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @user)

    access_opts = @obj.cookies.options_for(::AuthenticationClient::ACCESS_COOKIE_KEY)
    refresh_opts = @obj.cookies.options_for(::AuthenticationClient::REFRESH_COOKIE_KEY)

    assert_operator access_opts[:expires], :>, 4.minutes.from_now
    assert_operator access_opts[:expires], :<, 6.minutes.from_now
    assert_operator refresh_opts[:expires], :>, 29.days.from_now
    assert_operator refresh_opts[:expires], :<, 31.days.from_now
  end

  test "log_out clears session and current_client" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @user)
    @obj.send(:log_out)

    assert_not_predicate @obj, :logged_in?
    assert_nil @obj.current_client
  end

  test "log_out revokes refresh token and removes cookies" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @user)
    token = @obj.send(:current_session)

    assert_no_difference("ClientToken.count") { @obj.send(:log_out) }

    assert_predicate token.reload, :revoked?
    assert_nil @obj.cookies[::AuthenticationClient::ACCESS_COOKIE_KEY]
    assert_nil @obj.cookies.encrypted[::AuthenticationClient::REFRESH_COOKIE_KEY]
  end

  test "log_in keeps auth cookies host-only for __Host prefix compatibility" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    @obj.request.host = "id.app.localhost"

    @obj.send(:log_in, @user)

    assert_not @obj.cookies.options_for(::AuthenticationClient::ACCESS_COOKIE_KEY).key?(:domain)
    assert_not @obj.cookies.options_for(::AuthenticationClient::REFRESH_COOKIE_KEY).key?(:domain)
  end

  test "log_in returns tokens hash" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    tokens = @obj.send(:log_in, @user)

    assert_kind_of Hash, tokens
    assert tokens[:access_token]
    assert tokens[:refresh_token]
    assert_equal "Bearer", tokens[:token_type]
    assert_equal ::AuthenticationBase::ACCESS_TOKEN_TTL.to_i, tokens[:expires_in]
  end

  test "log_in creates device_session and uses it as access token sid" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    tokens = @obj.send(:log_in, @user)
    token = @obj.send(:current_session)
    payload = AuthenticationToken.decode(
      tokens[:access_token],
      host: @obj.request.host,
      resource_type: "client",
    )

    assert_predicate token.device_session, :present?
    assert_equal token.device_session.public_id, payload["sid"]
    assert_equal token.device_session.public_id, @obj.send(:current_session_public_id)
    assert_equal token.id, token.device_session.current_refresh_token_id
    assert_equal token.refresh_token_family_id, token.device_session.refresh_token_family_id
  end

  test "log_out revokes only current device_session and leaves another device active" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    other = DummyClass.new
    other.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    @obj.send(:log_in, @user)
    first_token = @obj.send(:current_session)
    first_device_session = first_token.device_session

    other.send(:log_in, @user)
    second_token = other.send(:current_session)
    second_device_session = second_token.device_session

    @obj.send(:log_out)

    assert_predicate first_token.reload, :revoked?
    assert_predicate first_device_session.reload, :revoked?
    assert_not_predicate second_token.reload, :revoked?
    assert_not_predicate second_device_session.reload, :revoked?
  end

  test "build_refreshed_session caps cookie and jwt expiry to discarded_at" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    freeze_time do
      token = ClientToken.create!(
        user: @user,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        discarded_at: 20.minutes.from_now,
      )

      result = @obj.send(:build_refreshed_session, @user, token, "refresh-token")
      payload = AuthenticationToken.decode(
        result[:access_token],
        host: @obj.request.host,
        resource_type: "client",
      )

      access_opts = @obj.cookies.options_for(::AuthenticationClient::ACCESS_COOKIE_KEY)
      refresh_opts = @obj.cookies.options_for(::AuthenticationClient::REFRESH_COOKIE_KEY)

      expected_access_expiry = ::AuthenticationBase::ACCESS_TOKEN_TTL.from_now

      assert_in_delta expected_access_expiry.to_i, payload["exp"], 1
      assert_in_delta expected_access_expiry.to_i, access_opts[:expires].to_i, 1
      assert_in_delta token.discarded_at.to_i, refresh_opts[:expires].to_i, 1
      assert_equal ::AuthenticationBase::ACCESS_TOKEN_TTL.to_i, result[:expires_in]
    end
  end

  test "log_in skips cookies for JSON format" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    @obj.request.format.format_type = :json

    @obj.send(:log_in, @user)

    assert @obj.cookies[::AuthenticationClient::ACCESS_COOKIE_KEY]
    assert @obj.cookies.encrypted[::AuthenticationClient::REFRESH_COOKIE_KEY]
  end

  test "extract_access_token from Authorization header" do
    token = "sample_jwt_token"
    @obj.request.headers["Authorization"] = "Bearer #{token}"

    extracted = @obj.send(:extract_access_token, ::AuthenticationClient::ACCESS_COOKIE_KEY)

    assert_equal token, extracted
  end

  test "extract_access_token accepts lowercase authorization scheme" do
    token = "sample_jwt_token"
    @obj.request.headers["Authorization"] = "bearer #{token}"

    extracted = @obj.send(:extract_access_token, ::AuthenticationClient::ACCESS_COOKIE_KEY)

    assert_equal token, extracted
  end

  test "extract_access_token from Cookie when no Authorization header" do
    token = "cookie_jwt_token"
    @obj.cookies[::AuthenticationClient::ACCESS_COOKIE_KEY] = token

    extracted = @obj.send(:extract_access_token, ::AuthenticationClient::ACCESS_COOKIE_KEY)

    assert_equal token, extracted
  end

  test "extract_access_token prioritizes Authorization header over Cookie" do
    header_token = "header_jwt_token"
    cookie_token = "cookie_jwt_token"
    @obj.request.headers["Authorization"] = "Bearer #{header_token}"
    @obj.cookies[::AuthenticationClient::ACCESS_COOKIE_KEY] = cookie_token

    extracted = @obj.send(:extract_access_token, ::AuthenticationClient::ACCESS_COOKIE_KEY)

    assert_equal header_token, extracted
  end

  test "current_client works with Bearer token" do
    @obj.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    token_record =
      OrgTicketRecord.connected_to(role: :writing) do
        ClientToken.create!(user: @user)
      end

    # Generate access token using AuthenticationToken
    access_token = AuthenticationToken.encode(
      @user,
      host: @obj.request.host,
      session_public_id: token_record.public_id,
      resource_type: "client",
    )
    @obj.request.headers["Authorization"] = "Bearer #{access_token}"

    assert_equal @user, @obj.current_client
  end

  test "log_in hard rejects when active and restricted sessions already exist" do
    2.times do
      token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
      token.rotate_refresh_token!
    end
    restricted = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted.rotate_refresh_token!(discarded_at: 15.minutes.from_now)
    before_ids = ClientToken.where(user_id: @user.id).order(:id).pluck(:id, :user_token_status_id, :discarded_at)

    result = @obj.send(:log_in, @user, require_totp_check: false)

    assert_equal :session_limit_hard_reject, result[:status]
    assert_equal :forbidden, result[:http_status]
    assert_equal AuthenticationBase::SESSION_LIMIT_HARD_REJECT_MESSAGE, result[:message]
    assert_equal before_ids,
                 ClientToken.where(user_id: @user.id).order(:id).pluck(:id, :user_token_status_id, :discarded_at)
  end

  test "log_in issues restricted session with 15 minute ttl when active sessions reach limit" do
    2.times do
      token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
      token.rotate_refresh_token!
    end

    freeze_time do
      result = @obj.send(:log_in, @user, require_totp_check: false)

      assert_equal :success, result[:status]
      assert result[:restricted]

      restricted = ClientToken.where(user_id: @user.id, user_token_status_id: ClientTokenStatus::RESTRICTED).order(:created_at).last

      assert_not_nil restricted
      assert_in_delta 15.minutes.from_now.to_i, restricted.discarded_at.to_i, 1
    end
  end
end
