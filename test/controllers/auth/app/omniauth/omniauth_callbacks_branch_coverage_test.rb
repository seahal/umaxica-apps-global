# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthAppOmniauthCallbacksBranchCoverageTest < ActiveSupport::TestCase
  test "failure ignores duplicate google callback after login" do
    c = Auth::App::Omniauth::OmniauthCallbacksController.new
    c.request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET")
    c.response = ActionDispatch::TestResponse.new
    session = { SocialAuth::SOCIAL_INTENT_SESSION_KEY => "login" }
    redirects = []
    c.define_singleton_method(:session) { session }
    c.define_singleton_method(:params) { ActionController::Parameters.new(message: "invalid_credentials", strategy: "google") }
    c.define_singleton_method(:logged_in?) { true }
    c.define_singleton_method(:redirect_to) { |path| redirects << path }
    c.define_singleton_method(:social_auth_success_redirect_path) { "/settings" }
    c.failure

    assert_equal ["/settings"], redirects
  end
end
