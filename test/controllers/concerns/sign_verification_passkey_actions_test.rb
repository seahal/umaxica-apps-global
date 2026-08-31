# typed: false
# frozen_string_literal: true

require "test_helper"

class SignVerificationPasskeyActionsTest < ActiveSupport::TestCase
  class Harness
    include SignVerificationPasskeyActions

    attr_accessor :render_args, :consumed, :failed, :prepared

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
      method == :passkey
    end

    def prepare_passkey_challenge!
      self.prepared = true
    end

    def verify_passkey!
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

  test "new prepares a challenge and renders the passkey page" do
    harness = Harness.new

    harness.new

    assert harness.prepared
    assert_equal [:new, { status: :ok }], harness.render_args
  end

  test "create consumes the session after a valid assertion" do
    harness = Harness.new

    harness.create

    assert_equal :passkey, harness.consumed
  end

  test "create reissues a challenge after a failed assertion" do
    harness = Harness.new
    harness.define_singleton_method(:verify_passkey!) { false }

    harness.create

    assert_equal :passkey, harness.failed
    assert harness.prepared
    assert_equal [:new, { status: :unprocessable_content }], harness.render_args
  end

  test "new and create stop without a step-up session" do
    harness = Harness.new
    harness.define_singleton_method(:require_step_up_session!) { false }

    assert_nil harness.new
    assert_nil harness.create
  end
end
