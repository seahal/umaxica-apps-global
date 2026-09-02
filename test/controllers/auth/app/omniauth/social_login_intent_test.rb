# typed: false
# frozen_string_literal: true

require "test_helper"

# A verified social callback still has to pass the same account checks as any
# other sign-in. An account that may no longer sign in is returned to the entry
# page rather than signed in, and a commit that reports anything other than
# success is recorded and handled as a failure rather than treated as a login.
class Auth::App::Omniauth::SocialLoginIntentTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Auth::App::Omniauth::OmniauthCallbacksController
    attr_accessor :redirected, :login_result_value, :failure_handled, :params_hash

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def redirect_to(*args, **kwargs)
      self.redirected = [args, kwargs]
    end

    def sign_in(*, **) = login_result_value

    def handle_login_failure(result, provider_name, user)
      self.failure_handled = [result, provider_name, user]
    end

    def external_authentication_method_locked?(**) = false

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    @harness.params_hash = { ri: "jp" }
    @harness.request = ActionDispatch::TestRequest.create
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
  end

  test "an account that may no longer sign in is returned to the entry page" do
    @user.update!(status_id: ClientStatus::RESERVED)

    @harness.invoke(:handle_login_intent, @user, "google", false, pt: nil)

    assert_includes @harness.redirected.first.first, "/sign/in"
  end

  test "a callback with no account at all is returned to the entry page" do
    @harness.invoke(:handle_login_intent, nil, "google", false, pt: nil)

    assert_includes @harness.redirected.first.first, "/sign/in"
  end

  test "a commit that does not report success is recorded and handled as a failure" do
    @harness.login_result_value = { status: :login_cooldown }
    recorded = []

    Rails.logger.stub(:warn, ->(*args, &block) { recorded << (args.first || block&.call).to_s }) do
      @harness.invoke(:handle_login_intent, @user, "google", false, pt: nil)
    end

    assert_equal :login_cooldown, @harness.failure_handled.first.fetch(:status)
    assert(recorded.any? { |line| line.include?("sign.social.omniauth.login_failed") })
  end
end
