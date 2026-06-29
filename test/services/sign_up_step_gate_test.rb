# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class SignUpStepGateTest < ActiveSupport::TestCase
  test "for_show falls back to the session sequence id when the locator payload is missing" do
    session = {}
    cycle = fake_cycle(public_id: "seq-123")
    session[:auth_app_up_sequence_id] = cycle.public_id
    controller = gate_controller(session)

    ClientSignUpFlow.stub(:find_by, cycle) do
      gate = SignUpStepGate.for_show(controller: controller, surface: :app, family: "google", step: :confirmation)

      assert_predicate gate, :success?
      assert_equal cycle, gate.ticket
      assert_equal :ok, gate.status
    end
  end

  test "for_show prefers the controller ticket fallback when the locator is empty" do
    session = {}
    cycle = fake_cycle(public_id: "seq-456")
    controller = gate_controller(session)
    controller.define_singleton_method(:current_sign_up_flow_ticket) { cycle }

    gate = SignUpStepGate.for_show(controller: controller, surface: :app, family: "google", step: :confirmation)

    assert_predicate gate, :success?
    assert_equal cycle, gate.ticket
  end

  test "for_show still requires a ticket when neither locator nor sequence id is present" do
    controller = gate_controller({})

    gate = SignUpStepGate.for_show(controller: controller, surface: :app, family: "google", step: :confirmation)

    assert_equal :invalid, gate.status
    assert_equal ["ticket is required"], gate.errors
  end

  private

  def gate_controller(session)
    Class.new do
      define_method(:initialize) do |session_arg|
        @session = session_arg
      end

      define_method(:session) do
        @session
      end

      define_method(:params) do
        {}
      end

      define_method(:sign_up_ticket_public_id) do
        @session[:auth_app_up_sequence_id]
      end

      define_method(:sign_app_sign_up_check_google_confirmation_path) do |_args|
        "/sign/up/check/google/confirmation"
      end

      define_method(:sign_app_sign_up_check_google_birthdate_path) do |_args|
        "/sign/up/check/google/birthdate"
      end
    end.new(session)
  end

  def fake_cycle(public_id:)
    Struct.new(:public_id).new(public_id).tap do |cycle|
      cycle.define_singleton_method(:entry_method) { "google" }
      cycle.define_singleton_method(:completed_requirements) { {} }
      cycle.define_singleton_method(:step) { "confirmation" }
      cycle.define_singleton_method(:expired?) { false }
      cycle.define_singleton_method(:lapsed?) { false }
      cycle.define_singleton_method(:sign_up_terminal?) { false }
      cycle.define_singleton_method(:sign_up_checkpoint_pending?) { true }
    end
  end
end
