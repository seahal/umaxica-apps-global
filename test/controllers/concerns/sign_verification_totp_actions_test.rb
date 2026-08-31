# typed: false
# frozen_string_literal: true

require "test_helper"

class SignVerificationTotpActionsTest < ActiveSupport::TestCase
  class Harness
    include SignVerificationTotpActions

    attr_accessor :render_args, :consumed, :failed, :errors

    def require_step_up_session!
      true
    end

    def redirect_if_recent_verification_for_get!
      false
    end

    def redirect_if_recent_verification_for_post!
      false
    end

    def require_method_available!(method)
      method == :totp
    end

    def cloudflare_turnstile_stealth_validation
      { "success" => true }
    end

    delegate :t, to: :I18n

    def verify_totp!
      true
    end

    def consume_step_up_session!(method:)
      self.consumed = method
    end

    def record_failed_step_up_attempt!(method)
      self.failed = method
    end

    def render(*args, **kwargs)
      self.render_args = [*args, kwargs]
    end
  end

  test "new returns unless a totp method is available" do
    harness = Harness.new
    harness.define_singleton_method(:require_method_available!) { |_method| false }

    assert_nil harness.new
  end

  test "create renders new when turnstile stealth validation fails" do
    harness = Harness.new
    harness.define_singleton_method(:cloudflare_turnstile_stealth_validation) { { "success" => false } }

    harness.create

    assert_equal I18n.t("turnstile_error"), harness.instance_variable_get(:@verification_errors).first
    assert_equal [:new, { status: :unprocessable_content }], harness.render_args
  end

  test "create consumes the step-up session after a valid totp" do
    harness = Harness.new

    harness.create

    assert_equal :totp, harness.consumed
  end

  test "create records a failed attempt when totp verification fails" do
    harness = Harness.new
    harness.define_singleton_method(:verify_totp!) { false }

    harness.create

    assert_equal :totp, harness.failed
    assert_equal [:new, { status: :unprocessable_content }], harness.render_args
  end

  test "new and create stop without a step-up session" do
    harness = Harness.new
    harness.define_singleton_method(:require_step_up_session!) { false }

    assert_nil harness.new
    assert_nil harness.create
  end
end
