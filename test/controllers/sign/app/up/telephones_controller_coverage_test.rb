# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Sign::Up::TelephonesControllerCoverageTest < ActiveSupport::TestCase
  class FakeFlow < Struct.new(:current, :cleared)
    def clear!
      self.cleared = true
    end
  end

  class FakeTelephone < Struct.new(
    :public_id, :user_telephone_status_id, :otp_expired, :number_digest, :locked_value,
    :reregistration_window_active_value, :confirm_policy, :confirm_using_mfa, :changed_value,
    :user_id, :destroyed, :otp_last_sent_at, :otp_expires_at,
  )
    def errors
      @errors ||= ActiveModel::Errors.new(self)
    end

    def otp_expired?
      otp_expired
    end

    def locked?
      locked_value
    end

    def reregistration_window_active?
      reregistration_window_active_value
    end

    def changed?
      changed_value
    end

    def save!
      true
    end

    def update!(**)
      true
    end

    def destroy!
      self.destroyed = true
    end
  end

  class Harness < Sign::App::Sign::Up::TelephonesController
    attr_accessor :params_hash, :session_hash, :rendered, :redirected, :flash_hash, :current_telephone,
                  :current_flow, :verification_result, :existing_telephone, :otp_result

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def session
      @session_hash ||= {}
    end

    def flash
      @flash_hash ||= {}
    end

    def request
      @request ||= Struct.new(:format).new(Struct.new(:json?, :html?).new(false, true))
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

    def sign_app_sign_up_check_telephone_otp_path(**kwargs)
      "/sign/up/check/telephone/otp?#{kwargs.compact.to_query}"
    end

    def sign_app_sign_up_telephone_path(**kwargs)
      "/sign/up/telephone/new?#{kwargs.compact.to_query}"
    end

    def sign_app_sign_in_path(**kwargs)
      "/sign/in?#{kwargs.compact.to_query}"
    end

    def t(key, **)
      key.to_s
    end

    delegate :clear!, to: :sign_up_flow_locator, prefix: true

    def cloudflare_turnstile_validation
      { "success" => true }
    end

    def verify_otp_code(_telephone, _submitted_code)
      otp_result || { success: true }
    end

    def increment_otp_attempts!(_telephone)
      @attempts_incremented = true
    end

    def perform_dummy_otp_generation
      @dummy_otp_generated = true
    end

    def generate_otp_for(_telephone)
      "123456"
    end

    def bind_sign_up_flow_to_telephone!(_telephone)
      @bound = true
    end

    def clear_otp(_telephone)
      @cleared_otp = true
    end

    def sign_up_flow_locator=(value)
      @sign_up_flow_locator = value
    end
  end

  setup do
    @controller = Harness.new
  end

  test "session helpers and rate limiting branches are covered" do
    registration = { "public_id" => "tel-1", "existing" => true, "expires_at" => 1.minute.from_now.to_i }
    @controller.session[:user_telephone_registration] = registration
    @controller.session[:user_telephone_otp_last_sent_at] = Time.current.to_i

    assert_equal "tel-1", @controller.send(:session_public_id_from_registration)
    assert @controller.send(:existing_signup_telephone_flow?, registration)
    assert_predicate @controller, :otp_resend_rate_limited?
  end

  test "valid_telephone_session? covers existing signup and fresh flow branches" do
    telephone = FakeTelephone.new(
      "tel-1", ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, false, nil, false, false,
      "1", "1", false, nil, false, nil, nil,
    )
    @controller.instance_variable_set(:@user_telephone, telephone)

    @controller.session[:user_telephone_registration] = {
      "public_id" => "tel-1",
      "existing" => true,
    }

    assert_predicate @controller, :valid_telephone_session?

    @controller.session.clear

    assert_predicate @controller, :valid_telephone_session?
  end

  test "telephone uniqueness and lookup helpers cover false and true branches" do
    telephone = FakeTelephone.new(
      "tel-1", ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, false, "digest", false,
      false, "1", "1", false, nil, false, nil, nil,
    )
    telephone.errors.add(:number, :taken)
    @controller.instance_variable_set(:@user_telephone, telephone)

    assert @controller.send(:telephone_uniqueness_only_error?, telephone)

    telephone.errors.add(:base, "other")

    assert_not @controller.send(:telephone_uniqueness_only_error?, telephone)

    ClientTelephone.stub(:find_by, telephone) do
      assert_equal telephone, @controller.send(:find_existing_telephone_by_digest)
    end
  end

  test "cleanup_pending_telephone_signup! clears locator and destroys pending unverified clients" do
    pending_user = Struct.new(:status_id, :destroyed) do
      def destroy!
        self.destroyed = true
      end
    end.new(ClientStatus::UNVERIFIED_WITH_SIGN_UP, false)
    pending_telephone = Struct.new(:user, :destroyed, :public_id) do
      def destroy!
        self.destroyed = true
      end
    end.new(pending_user, false, "tel-1")

    @controller.session[:user_telephone_registration] = { "public_id" => "tel-1" }

    @controller.sign_up_flow_locator
    ClientTelephone.stub(:find_by, pending_telephone) do
      @controller.send(:cleanup_pending_telephone_signup!)
    end

    assert @controller.instance_variable_get(:@sign_up_flow_locator).cleared
    assert pending_telephone.destroyed
    assert pending_user.destroyed
  end

  test "dispatch_existing_telephone_verification! writes registration state and sends otp" do
    telephone = FakeTelephone.new(
      "tel-2",
      ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
      false,
      nil,
      false,
      false,
      "1",
      "1",
      false,
      42,
      false,
      nil,
      1.minute.from_now,
    )
    @controller.current_flow = Struct.new(:public_id).new("flow-2")
    @controller.session[:ri] = "jp"

    delivered = nil
    SignTelephoneOtpDelivery.stub(:deliver!, ->(tel, otp) { delivered = [tel, otp] }) do
      @controller.send(:dispatch_existing_telephone_verification!, telephone)
    end

    assert_equal [telephone, "123456"], delivered
    assert_predicate @controller.session[:user_telephone_registration], :present?
    assert @controller.instance_variable_get(:@sign_up_flow_locator).cleared
  end

  test "verify_existing_telephone_code covers success and lockout branches" do
    telephone = FakeTelephone.new(
      "tel-3", ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, false, nil, true, false,
      "1", "1", false, nil, false, nil, nil,
    )
    @controller.instance_variable_set(:@user_telephone, telephone)
    @controller.params_hash = { user_telephone: { pass_code: "123456" } }
    @controller.otp_result = { success: false }

    assert_equal :locked, @controller.send(:verify_existing_telephone_code)
    assert @controller.instance_variable_defined?(:@attempts_incremented)

    telephone.locked_value = false
    @controller.otp_result = { success: true }

    assert @controller.send(:verify_existing_telephone_code)
  end

  test "verify_telephone_ownership! persists ownership flags and session state" do
    telephone = FakeTelephone.new(
      "tel-4", ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, false, nil, false, false,
      "0", "0", true, 42, false, nil, nil,
    )
    @controller.instance_variable_set(:@user_telephone, telephone)
    @controller.session[:user_telephone_registration] = {}

    @controller.send(:verify_telephone_ownership!)

    assert_equal "1", telephone.confirm_policy
    assert_equal "1", telephone.confirm_using_mfa
    assert @controller.instance_variable_get(:@cleared_otp)
    assert @controller.session[:user_telephone_registration]["otp_verified"]
    assert_equal "tel-4", @controller.session[:user_telephone_registration]["public_id"]
  end
end
