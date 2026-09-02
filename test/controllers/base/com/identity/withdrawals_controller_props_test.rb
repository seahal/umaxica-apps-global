# typed: false
# frozen_string_literal: true

require "test_helper"

# The withdrawal page shows exactly one of three states per section, and which
# one is decided from the timestamps the ceremony recorded. A visitor past the
# recovery window must be told recovery is no longer available rather than being
# shown a submit button that would be refused.
class Base::Com::Identity::WithdrawalsControllerPropsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Base::Com::Identity::WithdrawalsController
    attr_accessor :params_hash

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    @harness.params_hash = { ri: "jp" }
    @harness.request = ActionDispatch::TestRequest.create
  end

  test "a visitor past the recovery window is told recovery is no longer available" do
    @harness.instance_variable_set(:@recovery_available, false)
    @harness.instance_variable_set(:@recovery_available_at, 1.day.ago)

    props = @harness.invoke(:withdrawal_recovery_section_props)

    assert_equal I18n.t("sign.app.settings.withdrawal.recovery.unavailable"), props.fetch(:unavailable_message)
  end

  test "a visitor still inside the recovery window is shown when it closes" do
    @harness.instance_variable_set(:@recovery_available, false)
    @harness.instance_variable_set(:@recovery_available_at, 1.day.from_now)

    props = @harness.invoke(:withdrawal_recovery_section_props)

    assert_predicate props.fetch(:pending_message), :present?
  end

  test "a visitor who may end the withdrawal early is shown the submit target for this surface" do
    @harness.instance_variable_set(:@early_terminatable, true)

    props = @harness.invoke(:withdrawal_termination_section_props)

    assert_equal I18n.t("sign.app.settings.withdrawal.terminate.submit"), props.fetch(:submit_label)
    assert_includes props.fetch(:url), "/identity/withdrawal"
  end
end
