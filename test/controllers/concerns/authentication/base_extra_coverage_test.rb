# typed: false
# frozen_string_literal: true

require "test_helper"

class Authentication::BaseExtraCoverageTest < ActiveSupport::TestCase
  class FakeRequest
    attr_accessor :headers, :format, :host, :original_url, :remote_ip, :user_agent, :request_id, :fullpath,
                  :request_method

    def get?
      request_method == "GET"
    end

    def filtered_parameters
      {}
    end

    def parameters
      {}
    end

    def optional_port
      nil
    end

    def protocol
      "http://"
    end

    def path_parameters
      {}
    end

    def script_name
      ""
    end

    def routes
      Rails.application.routes
    end
  end

  class Harness < ApplicationController
    include Authentication::Base

    attr_accessor :session_hash, :request_obj, :rendered, :redirected, :marked_as_read

    def initialize
      super
      @session_hash = {}
      @headers = {}
      @request_obj = FakeRequest.new
      @request_obj.headers = @headers
      @request_obj.format = Struct.new(:json?).new(false)
      @request_obj.host = "localhost"
      @request_obj.original_url = "http://localhost"
      @request_obj.remote_ip = "127.0.0.1"
      @request_obj.user_agent = "TestAgent"
      @request_obj.request_id = "req-1"
      @request_obj.fullpath = "/test"
      @request_obj.request_method = "GET"
      @response_obj = Struct.new(:headers).new({})
    end

    def t(key)
      "translated:#{key}"
    end

    def epoch_seconds(time)
      time.to_i
    end

    def bulletin_association_for_resource
      return nil unless current_resource

      obj = Object.new
      def obj.unread
        @unread ||= Struct.new(:oldest_first).new(
          Struct.new(:first).new(
            Struct.new(:id, :mark_as_read!).new(1, true),
          ),
        )
      end

      def obj.find_by(id:)
        Struct.new(:id, :mark_as_read!).new(id, true)
      end
      obj
    end

    def session
      @session_hash
    end

    def request
      @request_obj
    end

    def render(args)
      @rendered = args
    end

    def redirect_to(path, options = {})
      @redirected = [path, options]
    end

    def jump_to_generated_url(url, fallback:)
      @redirected = [url, { fallback: fallback }]
    end

    # Abstract methods implementation
    def resource_class
      Client
    end

    def token_class
      ClientToken
    end

    def audit_class
      ClientChronicle
    end

    def resource_type
      "user"
    end

    def resource_foreign_key
      :user_id
    end

    def sign_in_url_with_pt(pt)
      "/sign_in?pt=#{pt}"
    end

    def am_i_user?
      true
    end

    def am_i_staff?
      false
    end

    def am_i_owner?
      false
    end

    def current_resource
      @current_resource
    end

    def current_resource=(res)
      @current_resource = res
    end
  end

  setup do
    @harness = Harness.new
  end

  test "maybe_inject_test_bulletin! injects session when in test env" do
    @harness.request.headers[Auth::IoKeys::Headers::TEST_BULLETIN] = { bulletin_id: 123 }.to_json
    @harness.maybe_inject_test_bulletin!

    assert_equal 123, @harness.session[Authentication::Base::BULLETIN_SESSION_KEY]["bulletin_id"]
  end

  test "bulletin_active? and bulletin_expired?" do
    @harness.session[Authentication::Base::BULLETIN_SESSION_KEY] = {
      "issued_at" => Time.current.to_i,
      "bulletin_id" => 1,
    }

    assert_predicate @harness, :bulletin_active?
    assert_not @harness.bulletin_expired?

    @harness.session[Authentication::Base::BULLETIN_SESSION_KEY]["issued_at"] = 3.hours.ago.to_i

    assert_predicate @harness, :bulletin_expired?
  end

  test "issue_bulletin! sets session" do
    @harness.current_resource = Client.new

    assert @harness.issue_bulletin!(kind: "welcome")
    assert_equal "welcome", @harness.session[Authentication::Base::BULLETIN_SESSION_KEY]["kind"]
  end

  test "refresh_bulletin_dimension! updates issued_at" do
    @harness.session[Authentication::Base::BULLETIN_SESSION_KEY] = { "issued_at" => 1.hour.ago.to_i }
    @harness.refresh_bulletin_dimension!(state: "refreshed")

    assert_operator @harness.session[Authentication::Base::BULLETIN_SESSION_KEY]["issued_at"], :>, 1.minute.ago.to_i
    assert_equal "refreshed", @harness.session[Authentication::Base::BULLETIN_SESSION_KEY]["state"]
  end

  test "consume_bulletin! clears session" do
    @harness.session[Authentication::Base::BULLETIN_SESSION_KEY] = { "bulletin_id" => 1 }
    @harness.current_resource = Client.new
    @harness.consume_bulletin!

    assert_nil @harness.session[Authentication::Base::BULLETIN_SESSION_KEY]
  end

  test "load_authentication_session handles missing session" do
    result = @harness.load_authentication_session("key", Client, "/login", "errors.messages.not_authorized")

    assert_nil result
    assert_equal ["/login", { notice: "translated:errors.messages.not_authorized" }], @harness.redirected
  end

  test "validate_session_expiry" do
    assert @harness.validate_session_expiry({ "expires_at" => 1.hour.from_now })
    assert_not @harness.validate_session_expiry({ "expires_at" => 1.hour.ago })
    assert @harness.validate_session_expiry({ "other" => 2.hours.from_now }, "other")
  end

  test "clear_authentication_session clears multiple keys" do
    @harness.session["a"] = 1
    @harness.session["b"] = 2
    @harness.clear_authentication_session("a", "b")

    assert_nil @harness.session["a"]
    assert_nil @harness.session["b"]
  end

  test "reject_logged_in_session renders unauthorized if logged in" do
    @harness.current_resource = Client.new
    @harness.request.request_method = "POST"
    @harness.reject_logged_in_session

    assert_equal :unauthorized, @harness.rendered[:status]
  end

  test "redirect_to_pt_or_default! jumps to pt" do
    token = @harness.send(:issue_authentication_path_target_token, "/target")

    @harness.redirect_to_pt_or_default!(token, default_path: "/default")

    assert_equal ["/target", { allow_other_host: false }], @harness.redirected
  end

  test "current_session_public_id returns extracted session id and memoizes it" do
    calls = 0
    @harness.define_singleton_method(:extract_access_token) do |_cookie_key|
      calls += 1
      "access-token"
    end
    @harness.request.host = "localhost"

    Authentication::Base::Token.stub(
      :extract_session_id_allow_expired,
      ->(token, host:, resource_type:, issuer: nil, audiences: nil) {
        assert_equal "access-token", token
        assert_equal "localhost", host
        assert_equal "user", resource_type
        assert_nil issuer
        assert_nil audiences
        "session-public-id"
      },
    ) do
      assert_equal "session-public-id", @harness.current_session_public_id
      assert_equal "session-public-id", @harness.current_session_public_id
    end

    assert_equal 1, calls
  end

  test "current_session_public_id returns nil when access token is missing" do
    @harness.define_singleton_method(:extract_access_token) do |_cookie_key|
      nil
    end

    assert_nil @harness.send(:current_session_public_id_from_access_token)
    assert_nil @harness.current_session_public_id
  end

  test "authenticate! redirects for html" do
    @harness.authenticate!

    uri = URI.parse(@harness.redirected.first)
    query = Rack::Utils.parse_nested_query(uri.query)

    assert_equal "/sign_in", uri.path
    assert_match(/--/, query["pt"])
    assert_equal "http://localhost/", @harness.send(:verify_authentication_pt_path, query["pt"])
  end

  test "authenticate! renders for json" do
    req = @harness.request
    req.define_singleton_method(:format) do
      Struct.new(:json?).new(true)
    end
    @harness.authenticate!

    assert_equal :unauthorized, @harness.rendered[:status]
  end

  test "log_out clears session and cookies" do
    @harness.current_resource = Client.new
    # Mock clear_auth_cookies! and destroy_refresh_token_from_cookie
    @harness.define_singleton_method(:clear_auth_cookies!) do
      nil
    end

    @harness.define_singleton_method(:destroy_refresh_token_from_cookie) do
      nil
    end

    @harness.define_singleton_method(:reset_session) do
      @session_hash.clear
    end
    @harness.session["user_id"] = 1
    @harness.log_out

    assert_empty @harness.session
  end

  test "epoch_seconds handles various types" do
    now = Time.current

    assert_equal now.to_i, @harness.epoch_seconds(now)
    assert_equal 60, @harness.epoch_seconds(1.minute)
    assert_equal 123, @harness.epoch_seconds("123")
    assert_equal 0, @harness.epoch_seconds(nil)
  end
end
