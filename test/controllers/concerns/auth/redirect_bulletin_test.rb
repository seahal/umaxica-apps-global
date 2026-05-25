# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthRedirectBulletinTest < ActiveSupport::TestCase
  class RedirectHarness
    include Authentication::Base

    attr_accessor :session_data, :params_data, :request_obj, :performed

    def initialize
      @session_data = {}
      @params_data = {}
      @request_obj = MockRequest.new
      @performed = false
    end

    def session
      @session_data
    end

    def params
      @params_data
    end

    def request
      @request_obj
    end

    def performed?
      @performed
    end

    def redirect_to(*_args)
      @performed = true
    end

    def render(*_args)
      @performed = true
    end

    def resource_type
      "user"
    end

    def resource_class
      Client
    end

    def token_class
      ClientToken
    end

    def audit_class
      ClientChronicle
    end

    def resource_foreign_key
      :user_id
    end

    def sign_in_url_with_return(_return_to)
      "/sign/in"
    end

    def am_i_user?
      false
    end

    def am_i_staff?
      false
    end

    def am_i_owner?
      false
    end
  end

  class MockRequest
    attr_accessor :host, :host_with_port, :remote_ip, :user_agent, :request_id, :fullpath

    def initialize
      @host = "example.com"
      @host_with_port = "example.com"
      @remote_ip = "127.0.0.1"
      @user_agent = "TestAgent"
      @request_id = "test-123"
      @fullpath = "/test"
    end

    def format
      MockFormat.new
    end

    def headers
      {}
    end
  end

  class MockFormat
    def json?
      false
    end

    def html?
      true
    end
  end

  setup do
    @harness = RedirectHarness.new
  end

  test "DEFAULT_RT_SESSION_KEY is defined" do
    assert_includes Authentication::Base::DEFAULT_RT_SESSION_KEY.to_s, "rt"
  end

  test "BULLETIN_SESSION_KEY is defined" do
    assert_equal :sign_in_checkpoint, Authentication::Base::BULLETIN_SESSION_KEY
  end

  test "BULLETIN_TIMEOUT is 2 hours" do
    assert_equal 2.hours, Authentication::Base::BULLETIN_TIMEOUT
  end

  test "preserve_redirect_parameter stores rt in session" do
    @harness.params_data[Auth::IoKeys::Params::RT] = "/dashboard"
    result = @harness.preserve_redirect_parameter

    assert_match(/--/, result)
    assert_equal result, @harness.session[Authentication::Base::DEFAULT_RT_SESSION_KEY]
  end

  test "preserve_redirect_parameter returns nil when no rt param" do
    result = @harness.preserve_redirect_parameter

    assert_nil result
    assert_nil @harness.session[Authentication::Base::DEFAULT_RT_SESSION_KEY]
  end

  test "retrieve_redirect_parameter returns and clears session value" do
    @harness.session[Authentication::Base::DEFAULT_RT_SESSION_KEY] = @harness.safe_encoded_rt("/dashboard")
    result = @harness.retrieve_redirect_parameter

    assert_match(/--/, result)
    assert_nil @harness.session[Authentication::Base::DEFAULT_RT_SESSION_KEY]
  end

  test "retrieve_redirect_parameter falls back to params" do
    @harness.params_data[Auth::IoKeys::Params::RT] = "/dashboard"
    result = @harness.retrieve_redirect_parameter

    assert_match(/--/, result)
  end

  test "peek_redirect_parameter returns without clearing" do
    @harness.session[Authentication::Base::DEFAULT_RT_SESSION_KEY] = @harness.safe_encoded_rt("/dashboard")
    result = @harness.peek_redirect_parameter

    assert_match(/--/, result)
    assert_equal result, @harness.session[Authentication::Base::DEFAULT_RT_SESSION_KEY]
  end

  test "build_redirect_params includes rt when present" do
    @harness.session[Authentication::Base::DEFAULT_RT_SESSION_KEY] = @harness.safe_encoded_rt("/dashboard")
    result = @harness.build_redirect_params(:notice, "Success")

    assert_equal "Success", result[:notice]
    assert_match(/--/, result[Auth::IoKeys::Params::RT])
  end

  test "build_notice_params creates notice hash" do
    result = @harness.build_notice_params("Success")

    assert_equal "Success", result[:notice]
  end

  test "build_alert_params creates alert hash" do
    result = @harness.build_alert_params("Warning")

    assert_equal "Warning", result[:alert]
  end

  test "safe return path accepts same-host absolute url as internal path" do
    result = @harness.send(:safe_return_path, "https://example.com/configuration/sessions?ri=jp")

    assert_equal "/configuration/sessions?ri=jp", result
  end

  test "safe return path rejects external absolute url" do
    result = @harness.send(:safe_return_path, "https://evil.example/configuration/sessions?ri=jp")

    assert_nil result
  end

  test "issue_bulletin! sets bulletin in session when unread bulletin exists" do
    mock_bulletin = Minitest::Mock.new
    mock_bulletin.expect(:id, 42)

    freeze_time do
      @harness.stub(:find_unread_bulletin, mock_bulletin) do
        result = @harness.issue_bulletin!(kind: "mfa", state: "pending")

        assert result
        bulletin = @harness.session[Authentication::Base::BULLETIN_SESSION_KEY]

        assert_equal "mfa", bulletin["kind"]
        assert_equal "pending", bulletin["state"]
        assert_equal Time.current.to_i, bulletin["issued_at"]
        assert_equal 42, bulletin["bulletin_id"]
      end
    end
  end

  test "issue_bulletin! returns false when no unread bulletin" do
    @harness.stub(:find_unread_bulletin, nil) do
      result = @harness.issue_bulletin!(kind: "mfa", state: "pending")

      assert_not result
      assert_nil @harness.session[Authentication::Base::BULLETIN_SESSION_KEY]
    end
  end

  test "bulletin_state returns nil when no bulletin" do
    assert_nil @harness.bulletin_state
  end

  test "bulletin_state returns hash with indifferent access" do
    @harness.session[Authentication::Base::BULLETIN_SESSION_KEY] = { "kind" => "mfa", "state" => "pending" }
    result = @harness.bulletin_state

    assert_equal "mfa", result[:kind]
    assert_equal "pending", result[:state]
  end

  test "bulletin_active? returns false when no bulletin" do
    assert_not @harness.bulletin_active?
  end

  test "bulletin_expired? returns true for old bulletin" do
    old_time = 3.hours.ago.to_i
    @harness.session[Authentication::Base::BULLETIN_SESSION_KEY] = {
      "issued_at" => old_time,
      "kind" => "mfa",
      "state" => "pending",
    }

    assert_predicate @harness, :bulletin_expired?
  end

  test "consume_bulletin! removes bulletin from session" do
    @harness.session[Authentication::Base::BULLETIN_SESSION_KEY] = { "kind" => "mfa" }
    @harness.consume_bulletin!

    assert_nil @harness.session[Authentication::Base::BULLETIN_SESSION_KEY]
  end

  test "refresh_bulletin_dimension! updates issued_at and state" do
    old_time = 1.hour.ago.to_i
    @harness.session[Authentication::Base::BULLETIN_SESSION_KEY] = {
      "issued_at" => old_time,
      "kind" => "mfa",
      "state" => "pending",
    }

    travel_to(1.second.from_now)
    @harness.refresh_bulletin_dimension!(state: "updated")
    bulletin = @harness.session[Authentication::Base::BULLETIN_SESSION_KEY]

    assert_operator bulletin["issued_at"], :>, old_time
    assert_equal "updated", bulletin["state"]
  end
end
