# typed: false
# frozen_string_literal: true

require "test_helper"

# Companion to the app-surface coverage test: the com sign-up email controller
# has the same guard set, and these branches decide whether a half-finished
# ceremony may continue. They are reached from session states an HTTP request
# cannot arrive in on its own -- a stale flow state, an existing-account flow
# whose stored id no longer matches the loaded record -- so they are pinned
# directly against the controller the way the app surface already is.
class Auth::Com::Sign::Up::EmailsControllerCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class FakeFlow < Struct.new(:current, :cleared)
    def clear!
      self.cleared = true
    end
  end

  class FakeEmail < Struct.new(:id, :visitor_email_status_id, :public_id)
    def otp_expired?
      @otp_expired ||= false
    end

    def otp_expired=(value)
      @otp_expired = value
    end
  end

  class FakeVisitor < Struct.new(:destroyed)
    def destroy!
      self.destroyed = true
    end
  end

  class Harness < Auth::Com::Sign::Up::EmailsController
    attr_accessor :params_hash, :rendered, :redirected, :current_flow, :reset_called

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def session
      @session_hash ||= {}
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

    def action_name
      params_hash&.dig(:action).to_s
    end

    # Path helpers on a controller resolve their host through the request, and
    # this harness has none. The guards under test only care that they redirected
    # to the entry page, so the helper is answered with the literal path.
    def new_auth_com_sign_up_email_path(**options)
      query = options.compact.to_query
      query.present? ? "/sign/up/email/new?#{query}" : "/sign/up/email/new"
    end
  end

  setup do
    @controller = Harness.new
  end

  test "a flow state that does not match the required step sends the visitor back to the entry page" do
    @controller.params_hash = { action: "edit", ri: "jp" }
    @controller.session[Auth::Com::Sign::Up::EmailsController::SESSION_KEY] = "init"

    @controller.send(:enforce_email_flow!)

    assert_equal [["/sign/up/email/new?ri=jp"], {}], @controller.redirected
  end

  test "an invalid session resets the flow and sends the visitor back to the entry page" do
    @controller.params_hash = { ri: "jp" }
    @controller.session[Auth::Com::Sign::Up::EmailsController::SESSION_KEY] = "email_created"
    @controller.session[Auth::Com::Sign::Up::EmailsController::EXISTING_EMAIL_SESSION_KEY] = 7

    @controller.send(:redirect_invalid_session)

    assert_equal "init", @controller.session[Auth::Com::Sign::Up::EmailsController::SESSION_KEY]
    assert_nil @controller.session[Auth::Com::Sign::Up::EmailsController::EXISTING_EMAIL_SESSION_KEY]
    assert_predicate @controller.sign_up_flow_locator.cleared, :present?
    assert_equal [["/sign/up/email/new?ri=jp"], {}], @controller.redirected
  end

  test "an existing-account flow only stays valid while the stored id still names the loaded email" do
    email = FakeEmail.new(7, VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP, "pub-7")
    @controller.instance_variable_set(:@user_email, email)
    @controller.session[Auth::Com::Sign::Up::EmailsController::EXISTING_EMAIL_SESSION_KEY] = email.id
    @controller.session[Auth::Com::Sign::Up::EmailsController::EXISTING_EMAIL_SKIP_OTP_SESSION_KEY] = true

    assert @controller.send(:valid_email_session?)

    @controller.session[Auth::Com::Sign::Up::EmailsController::EXISTING_EMAIL_SESSION_KEY] = email.id + 1

    assert_not @controller.send(:valid_email_session?)
  end

  test "an existing-account flow without the skip flag still depends on the code not having expired" do
    email = FakeEmail.new(9, VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP, "pub-9")
    @controller.instance_variable_set(:@user_email, email)
    @controller.session[Auth::Com::Sign::Up::EmailsController::EXISTING_EMAIL_SESSION_KEY] = email.id

    assert @controller.send(:valid_email_session?)

    email.otp_expired = true

    assert_not @controller.send(:valid_email_session?)
  end

  test "the existing-account email is loaded by the id the session carries" do
    email = FakeEmail.new(11, VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP, "pub-11")
    @controller.session[Auth::Com::Sign::Up::EmailsController::EXISTING_EMAIL_SESSION_KEY] = email.id

    VisitorEmail.stub(:find_by, email) do
      assert_equal email, @controller.send(:current_registration_email)
    end
  end

  test "cleanup destroys the pending visitor the abandoned flow created" do
    pending_visitor = FakeVisitor.new(false)
    @controller.current_flow = Struct.new(:principal_id).new(123)
    @controller.sign_up_flow_locator

    Visitor.stub(:find_by, pending_visitor) do
      @controller.send(:cleanup_pending_visitor_signup!)
    end

    assert pending_visitor.destroyed
  end

  test "cleanup does nothing when the flow never reached a principal" do
    @controller.current_flow = Struct.new(:principal_id).new(nil)
    @controller.sign_up_flow_locator

    assert_nil @controller.send(:cleanup_pending_visitor_signup!)
  end
end
