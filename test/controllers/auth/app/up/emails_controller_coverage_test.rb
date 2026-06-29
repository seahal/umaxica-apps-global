# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::App::Sign::Up::EmailsControllerCoverageTest < ActiveSupport::TestCase
  class FakeFlow < Struct.new(:current, :cleared)
    def clear!
      self.cleared = true
    end
  end

  class FakeEmail < Struct.new(:id, :user_email_status_id, :public_id)
    def errors
      @errors ||= ActiveModel::Errors.new(self)
    end

    def otp_expired?
      @otp_expired ||= false
    end

    def otp_expired=(value)
      @otp_expired = value
    end
  end

  class FakeUser < Struct.new(:destroyed, :status_id)
    def destroy!
      self.destroyed = true
    end
  end

  class Harness < Auth::App::Sign::Up::EmailsController
    attr_accessor :params_hash, :session_hash, :rendered, :redirected, :flash_hash, :current_flow

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def session
      @session_hash ||= {}
    end

    def flash
      @flash_hash ||= {}
    end

    def render(*args, **kwargs)
      self.rendered = [args, kwargs]
    end

    def redirect_to(*args, **kwargs)
      self.redirected = [args, kwargs]
    end

    def sign_up_flow_locator
      @sign_up_flow_locator ||= FakeFlow.new(current_flow, false)
    end

    # Mirror the real sequence-support concern: contact resolution goes through
    # the ticket lookup, which prefers the locator and falls back to the
    # sequence id. The harness exercises the locator branch.
    def current_sign_up_flow_ticket
      sign_up_flow_locator.current
    end

    def reset_email_flow!
      @reset_email_flow = true
    end

    def resolved_path_or_navigation_target
      "/resolved"
    end

    def signed_pt_token(value)
      value && "pt:#{value}"
    end

    def t(key, **)
      key.to_s
    end
  end

  setup do
    @controller = Harness.new
  end

  test "sign_up_email_digest_for_rate_limit normalizes the address and handles blank input" do
    @controller.params_hash = { user_email: { raw_address: "  Mixed@Example.COM " } }

    assert_equal Digest::SHA256.hexdigest("mixed@example.com"),
                 @controller.send(:sign_up_email_digest_for_rate_limit)

    @controller.params_hash = {}

    assert_nil @controller.send(:sign_up_email_digest_for_rate_limit)

    @controller.params_hash = { user_email: { raw_address: "not-an-email" } }

    assert_nil @controller.send(:sign_up_email_digest_for_rate_limit)
  end

  test "current_registration_email prefers the session email and falls back to the flow contact" do
    session_email = FakeEmail.new(11, ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, "pub-11")
    flow_email = FakeEmail.new(22, ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, "pub-22")

    @controller.session[SignEmailRegistrable::EXISTING_EMAIL_SESSION_KEY] = session_email.id

    ClientEmail.stub(:find_by, session_email) do
      assert_equal session_email, @controller.send(:current_registration_email)
    end

    @controller.session.clear
    @controller.current_flow = Struct.new(:pending_contact_type, :pending_contact_id).new("email", flow_email.id)

    ClientEmail.stub(:find_by, flow_email) do
      assert_equal flow_email, @controller.send(:current_registration_email)
    end
  end

  test "valid_email_session? covers the existing signup and fresh flow branches" do
    email = FakeEmail.new(7, ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, "pub-7")
    @controller.instance_variable_set(:@user_email, email)

    @controller.session[SignEmailRegistrable::EXISTING_EMAIL_SESSION_KEY] = email.id
    @controller.session[SignEmailRegistrable::EXISTING_EMAIL_SKIP_OTP_SESSION_KEY] = true

    assert_predicate @controller, :valid_email_session?

    @controller.session.clear

    assert_predicate @controller, :valid_email_session?
  end

  test "cleanup_pending_signup! clears the locator and destroys an unverified pending client" do
    pending_user = FakeUser.new(false, ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    flow = Struct.new(:principal_id).new(123)

    @controller.current_flow = flow
    @controller.sign_up_flow_locator

    Client.stub(:find_by, pending_user) do
      @controller.send(:cleanup_pending_signup!)
    end

    assert pending_user.destroyed
  end

  test "strip_user_owner_errors! removes ownership errors from the current email" do
    email = FakeEmail.new(7, ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, "pub-7")
    email.errors.add(:user, "bad")
    email.errors.add(:user_id, "bad")
    email.errors.add(:address, "bad")
    @controller.instance_variable_set(:@user_email, email)

    @controller.send(:strip_user_owner_errors!)

    assert_empty email.errors.where(:user)
    assert_empty email.errors.where(:user_id)
    assert_equal 1, email.errors.where(:address).count
  end

  test "current_sign_up_flow issues a new flow when the locator is empty" do
    locator = Struct.new(:current, :issued) do
      def issue!(flow)
        self.current = flow
        self.issued = flow
        flow
      end
    end.new(nil, nil)
    @controller.instance_variable_set(:@sign_up_flow_locator, locator)

    flow = Struct.new(:public_id).new("flow-1")
    @controller.define_singleton_method(:issue_sign_up_flow!) do
      @sign_up_flow_locator.issue!(flow)
    end

    result = @controller.send(:current_sign_up_flow)

    assert_equal "flow-1", result.public_id
    assert_equal "flow-1", locator.current.public_id
  end
end
