# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthRedirectTestController < ApplicationController
  include Authentication::Base

  public_strict!

  def trigger_redirect_with_notice
    session[Authentication::Base::DEFAULT_RT_SESSION_KEY] = params[:rt] if params[:rt].present?
    redirect_with_notice("/default_path", "This is a notice")
  end

  def trigger_redirect_with_alert
    session[Authentication::Base::DEFAULT_RT_SESSION_KEY] = params[:rt] if params[:rt].present?
    redirect_with_alert("/default_path", "This is an alert")
  end

  def trigger_add_rt_to_params
    session[Authentication::Base::DEFAULT_RT_SESSION_KEY] = params[:rt] if params[:rt].present?
    redirect_params = { action: "index" }
    add_rt_to_params!(redirect_params)
    render json: redirect_params
  end

  def trigger_issue_bulletin
    if issue_bulletin!(kind: "test_kind", state: "test_state")
      render plain: "issued"
    else
      render plain: "not_issued"
    end
  end

  def trigger_inject_test_bulletin
    maybe_inject_test_bulletin!
    render json: session[Authentication::Base::BULLETIN_SESSION_KEY] || {}
  end

  def am_i_user?; false; end

  def am_i_staff?; false; end

  def am_i_owner?; false; end

  def resource_type; "User"; end

  def resource_class; User; end

  def token_class; UserToken; end
end

class AuthRedirectBoosterTest < ActionDispatch::IntegrationTest
  setup do
    @routes = Rails.application.routes
    Rails.application.routes.draw do
      get "/auth_redirect/notice" => "auth_redirect_test#trigger_redirect_with_notice"
      get "/auth_redirect/alert" => "auth_redirect_test#trigger_redirect_with_alert"
      get "/auth_redirect/params" => "auth_redirect_test#trigger_add_rt_to_params"
      get "/auth_redirect/bulletin" => "auth_redirect_test#trigger_issue_bulletin"
      get "/auth_redirect/inject" => "auth_redirect_test#trigger_inject_test_bulletin"
      get "/auth_redirect/index" => "auth_redirect_test#trigger_redirect_with_notice" # dummy destination
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "redirect_with_notice without rt" do
    get "/auth_redirect/notice"

    assert_redirected_to "/default_path"
    assert_equal "This is a notice", flash[:notice]
  end

  test "redirect_with_notice with rt" do
    # Assuming rt is a valid base64 encoded URL
    # "L2F1dGhfcmVkaXJlY3QvaW5kZXg=" -> "/auth_redirect/index"
    rt = Base64.urlsafe_encode64("/auth_redirect/index")
    get "/auth_redirect/notice", params: { rt: rt }
    # jump_to_generated_url redirects
    assert_redirected_to "/auth_redirect/index"
    assert_equal "This is a notice", flash[:notice]
  end

  test "redirect_with_alert without rt" do
    get "/auth_redirect/alert"

    assert_redirected_to "/default_path"
    assert_equal "This is an alert", flash[:alert]
  end

  test "add_rt_to_params" do
    rt = Base64.urlsafe_encode64("/auth_redirect/index")
    get "/auth_redirect/params", params: { rt: rt }

    assert_response :success
    assert_equal rt, response.parsed_body["rt"]
  end

  test "issue_bulletin returns false when no bulletin" do
    get "/auth_redirect/bulletin"

    assert_equal "not_issued", response.body
  end

  test "inject_test_bulletin" do
    # Send test header
    get "/auth_redirect/inject", headers: { "X-TEST-BULLETIN" => { "some" => "data" }.to_json }

    assert_response :success
    assert_equal "data", response.parsed_body["some"]
  end
end
