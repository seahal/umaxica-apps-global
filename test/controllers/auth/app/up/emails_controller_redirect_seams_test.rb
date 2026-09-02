# typed: false
# frozen_string_literal: true

require "test_helper"

# The sign-up email step carries a return target through redirects it builds
# itself. A target that no longer re-signs must be dropped rather than passed on
# as given, and a session that has gone stale must reset the flow and say so on
# the entry page instead of leaving the applicant on a step it can no longer
# answer.
class Auth::App::Sign::Up::EmailsControllerRedirectSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Auth::App::Sign::Up::EmailsController
    attr_accessor :params_hash, :signed_pt_result, :redirected, :reset_called

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def session = @session_hash ||= {}

    def reset_email_flow!
      self.reset_called = true
    end

    def signed_pt_token(_value) = signed_pt_result

    def build_notice_params(message) = { notice: message }

    def new_auth_app_sign_up_email_path(options = {}) = "/sign/up/email/new?#{options.to_query}"

    def redirect_to(*args, **kwargs)
      self.redirected = [args, kwargs]
    end

    def t(key, **) = key.to_s

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
  end

  test "a stale session resets the flow and returns to the entry page with a notice" do
    @harness.invoke(:redirect_invalid_session)

    assert @harness.reset_called
    assert_includes @harness.redirected.first.first, "notice="
  end

  test "a return target that no longer re-signs is dropped rather than passed on" do
    @harness.signed_pt_result = nil
    redirect_params = { ri: "jp", pt: "untrusted" }

    @harness.invoke(:sanitize_redirect_params!, redirect_params)

    assert_equal({ ri: "jp" }, redirect_params)
  end

  test "a return target that re-signs is replaced by the signed form" do
    @harness.signed_pt_result = "signed-pt"
    redirect_params = { ri: "jp", pt: "untrusted" }

    @harness.invoke(:sanitize_redirect_params!, redirect_params)

    assert_equal({ ri: "jp", pt: "signed-pt" }, redirect_params)
  end

  test "registration parameters supplied as a plain hash are permitted the same way" do
    @harness.params_hash = { user_email: { raw_address: "someone@example.com", confirm_policy: "1" } }

    permitted = @harness.invoke(:registration_email_params)

    assert_equal "someone@example.com", permitted[:raw_address]
    assert_predicate permitted, :permitted?
  end

  test "a request with no registration scope at all yields no parameters" do
    @harness.params_hash = {}

    assert_nil @harness.invoke(:registration_email_params)
  end
end
