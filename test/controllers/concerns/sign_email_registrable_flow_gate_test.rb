# typed: false
# frozen_string_literal: true

require "test_helper"

# Sign-up by email is a three-state flow held in the session, and every action is
# declared to require one state. Arriving at a later step without having passed
# the earlier one has to restart the flow rather than proceed, or the address
# verification step could be skipped entirely.
class SignEmailRegistrableFlowGateTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include ::SignEmailRegistrable

    attr_accessor :session, :action, :flash, :redirects

    def initialize
      @session = {}
      @flash = {}
      @redirects = []
    end

    def invoke(name, ...) = send(name, ...)

    def action_name = action

    def t(key, **) = key

    def redirect_to(path) = redirects << path

    def new_sign_app_sign_up_email_path = "/sign/up/email/new"
  end

  def harness_at(action, state: nil)
    harness = Harness.new
    harness.action = action.to_s
    harness.session[::SignEmailRegistrable::SESSION_KEY] = state if state
    harness
  end

  test "an action with no declared state requirement is left alone" do
    harness = harness_at(:index)

    assert_nil harness.invoke(:enforce_email_flow!)
    assert_empty harness.redirects
  end

  # Entering at the start is always allowed, and doing so clears any half-finished
  # attempt so a stale existing-address decision cannot carry into the new one.
  test "entering at the start resets a flow that was already part-way through" do
    harness = harness_at(:new, state: ::SignEmailRegistrable::STATE_EMAIL_CREATED)
    harness.session[::SignEmailRegistrable::EXISTING_EMAIL_SESSION_KEY] = 7
    harness.session[::SignEmailRegistrable::EXISTING_EMAIL_SKIP_OTP_SESSION_KEY] = true
    harness.session[::SignEmailRegistrable::DUMMY_EXISTING_EMAIL_SESSION_KEY] = true

    harness.invoke(:enforce_email_flow!)

    assert_equal ::SignEmailRegistrable::STATE_INIT, harness.session[::SignEmailRegistrable::SESSION_KEY]
    assert_empty harness.redirects
    assert_nil harness.session[::SignEmailRegistrable::EXISTING_EMAIL_SESSION_KEY]
    assert_nil harness.session[::SignEmailRegistrable::EXISTING_EMAIL_SKIP_OTP_SESSION_KEY]
    assert_nil harness.session[::SignEmailRegistrable::DUMMY_EXISTING_EMAIL_SESSION_KEY]
  end

  test "an action reached in its declared state proceeds" do
    harness = harness_at(:update, state: ::SignEmailRegistrable::STATE_EMAIL_CREATED)

    assert_nil harness.invoke(:enforce_email_flow!)
    assert_empty harness.redirects
  end

  test "an action reached out of order restarts the flow instead of proceeding" do
    {
      edit: ::SignEmailRegistrable::STATE_INIT,
      update: ::SignEmailRegistrable::STATE_EMAIL_VERIFIED,
      show: ::SignEmailRegistrable::STATE_EMAIL_CREATED,
      destroy: nil,
    }.each do |action, state|
      harness = harness_at(action, state: state)

      harness.invoke(:enforce_email_flow!)

      assert_equal ["/sign/up/email/new"], harness.redirects, "#{action} from #{state.inspect}"
      assert_equal "sign.app.registration.email.flow.invalid", harness.flash[:alert]
    end
  end

  test "the pending and verified statuses are the sign-up specific ones" do
    harness = Harness.new

    assert_equal ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, harness.invoke(:pending_email_status_id)
    assert_equal ClientEmailStatus::VERIFIED_WITH_SIGN_UP, harness.invoke(:verified_email_status_id)
  end
end
