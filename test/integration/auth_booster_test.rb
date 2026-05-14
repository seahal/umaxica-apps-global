# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthBoosterTest < ActionDispatch::IntegrationTest
  class DummyAuthController < ApplicationController
    include Authentication::Base

    class UserAudit
      def self.create!(*args)
      end
    end

    def resource_class
      User
    end

    def token_class
      UserToken
    end

    def audit_class
      UserAudit
    end

    def resource_type
      "user"
    end

    def resource_foreign_key
      :user_id
    end

    def sign_in_url_with_return(return_to)
      "/login?rt=#{return_to}"
    end

    def sign_app_edge_v0_token_dbsc_path
      "/dummy/dbsc"
    end

    def login_action
      user = User.first
      result = log_in(user, record_login_audit: false, token_kind_id: "BROWSER_WEB", require_totp_check: false)
      render json: result
    end

    def logout_action
      log_out
      render plain: "ok"
    end

    def transparent_refresh_action
      transparent_refresh_access_token
      render plain: current_resource ? "ok" : "fail"
    end

    def check_auth
      authenticate!
      render plain: "ok" if performed? == false
    end

    def reject_logged
      reject_logged_in_session
      render plain: "ok" if performed? == false
    end

    def ensure_not_logged
      ensure_not_logged_in
      render plain: "ok" if performed? == false
    end

    def test_session_helpers
      # store_authentication_session
      store_authentication_session(:test_key, 123)

      # validate_session_expiry
      data1 = { "expires_at" => 1.hour.from_now.to_i }
      data2 = { "expires_at" => 1.hour.ago.to_i }
      valid1 = validate_session_expiry(data1)
      valid2 = validate_session_expiry(data2)

      # clear_authentication_session
      clear_authentication_session(:test_key)

      render json: {
        valid1: valid1,
        valid2: valid2,
        session_cleared: session[:test_key].nil?,
      }
    end

    def test_load_session_record
      session[:user_id] = User.first&.id
      record1 = load_session_record(:user_id, User, custom: ->(_u) { true })
      record2 = load_session_record(:user_id, User, custom: ->(_u) { false })

      render json: {
        record1_present: record1.present?,
        record2_present: record2.present?,
      }
    end

    def test_validate_session_with_expiry
      session[:user_id] = User.first&.id
      load_authentication_session(:user_id, User, "/login", "auth.unauthorized") do |u|
        u.present?
      end

      session[:user_id] = 999_999
      load_authentication_session(:user_id, User, "/login", "auth.unauthorized") do |u|
        u.present?
      end unless performed?

      render plain: "ok" unless performed?
    end
  end

  setup do
    host! "id.com.localhost"
    Rails.application.routes.draw do
      post "test_auth_login" => "auth_booster_test/dummy_auth#login_action"
      post "test_auth_logout" => "auth_booster_test/dummy_auth#logout_action"
      post "test_auth_refresh" => "auth_booster_test/dummy_auth#transparent_refresh_action"
      get "test_auth_check" => "auth_booster_test/dummy_auth#check_auth"
      get "test_auth_reject" => "auth_booster_test/dummy_auth#reject_logged"
      get "test_auth_ensure" => "auth_booster_test/dummy_auth#ensure_not_logged"
      get "test_session_helpers" => "auth_booster_test/dummy_auth#test_session_helpers"
      get "test_load_session_record" => "auth_booster_test/dummy_auth#test_load_session_record"
      get "test_validate_session_with_expiry" => "auth_booster_test/dummy_auth#test_validate_session_with_expiry"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "session helpers" do
    get "/test_session_helpers"

    assert_response :success
    data = response.parsed_body

    assert data["valid1"]
    assert_not data["valid2"]
    assert data["session_cleared"]
  end

  test "load session record" do
    UserStatus.find_or_create_by!(id: 1)
    User.create!(id: 1, status_id: 1) unless User.exists?(1)
    get "/test_load_session_record"

    assert_response :success
    data = response.parsed_body

    assert data["record1_present"]
    assert_not data["record2_present"]
  end

  test "validate session with expiry" do
    UserStatus.find_or_create_by!(id: 1)
    User.create!(id: 1, status_id: 1) unless User.exists?(1)
    get "/test_validate_session_with_expiry"

    assert_response :redirect
    assert_equal I18n.t("auth.unauthorized"), flash[:notice]
  end

  test "login creates session and sets cookies" do
    UserStatus.find_or_create_by!(id: 1)
    User.create!(id: 1, status_id: 1) unless User.exists?(1)
    post "/test_auth_login"

    assert_response :success
    assert response.cookies.key?(Auth::CookieName.access)
    assert response.cookies.key?(Auth::CookieName.refresh)
  end

  test "logout clears cookies" do
    UserStatus.find_or_create_by!(id: 1)
    User.create!(id: 1, status_id: 1) unless User.exists?(1)
    post "/test_auth_login"
    post "/test_auth_logout"

    assert_response :success
    assert_predicate response.cookies[Auth::CookieName.access], :blank?
    assert_predicate response.cookies[Auth::CookieName.refresh], :blank?
  end

  test "transparent refresh" do
    UserStatus.find_or_create_by!(id: 1)
    User.create!(id: 1, status_id: 1) unless User.exists?(1)
    post "/test_auth_login"

    # We need to simulate the request with cookies set
    response.cookies[Auth::CookieName.access]
    refresh_cookie = response.cookies[Auth::CookieName.refresh]
    cookies[Auth::CookieName.refresh] = refresh_cookie

    # Intentionally don't set access cookie so it triggers transparent refresh
    post "/test_auth_refresh"

    assert_response :success
    assert_equal "ok", response.body
  end

  test "check auth blocks unauthenticated" do
    get "/test_auth_check"

    assert_response :redirect
    assert_redirected_to "/login?rt=#{Base64.urlsafe_encode64("http://id.com.localhost/test_auth_check")}"
  end

  test "check auth allows authenticated" do
    UserStatus.find_or_create_by!(id: 1)
    User.create!(id: 1, status_id: 1) unless User.exists?(1)
    post "/test_auth_login"

    access_cookie = response.cookies[Auth::CookieName.access]
    cookies[Auth::CookieName.access] = access_cookie

    get "/test_auth_check"

    assert_response :success
  end

  test "reject logged in session" do
    UserStatus.find_or_create_by!(id: 1)
    User.create!(id: 1, status_id: 1) unless User.exists?(1)
    post "/test_auth_login"

    access_cookie = response.cookies[Auth::CookieName.access]
    cookies[Auth::CookieName.access] = access_cookie

    get "/test_auth_reject"

    assert_response :redirect
    assert_redirected_to "/"
  end

  test "ensure not logged in" do
    UserStatus.find_or_create_by!(id: 1)
    User.create!(id: 1, status_id: 1) unless User.exists?(1)
    post "/test_auth_login"

    access_cookie = response.cookies[Auth::CookieName.access]
    cookies[Auth::CookieName.access] = access_cookie

    get "/test_auth_ensure"

    assert_response :unauthorized
  end
end
