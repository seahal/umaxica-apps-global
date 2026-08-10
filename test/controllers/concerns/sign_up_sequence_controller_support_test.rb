# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpSequenceControllerSupportCoverageTest < ActiveSupport::TestCase
  class Harness
    include SignUpSequenceControllerSupport

    attr_accessor :params_value, :surface, :rendered

    def params = params_value || {}

    def sign_up_surface = surface || :app

    def performed? = false

    def render(**options) = self.rendered = options

    def sign_up_actor_authentication = :authentication

    def sign_up_pending_actor = :pending_actor

    def sign_up_default_sign_in_path = "/sign-in"

    def sign_up_handoff_pt = "handoff"

    def sign_up_handoff_redirect_url(*) = "/next"

    def redirect_to(value) = self.rendered = { redirect_to: value }

    def redirect_to_sign_in_sequence!(pt:) = self.rendered = { sign_in_sequence: pt }

    def invoke(name, ...) = send(name, ...)
  end

  Result = Struct.new(:status)

  test "result statuses map to stable HTTP responses" do
    harness = Harness.new
    expected = {
      ok: :ok,
      advanced: :ok,
      completed: :ok,
      sign_in_handoff_accepted: :ok,
      blocked: :forbidden,
      unauthorized: :forbidden,
      expired: :gone,
      invalid_transition: :unprocessable_content,
    }

    expected.each do |result_status, http_status|
      harness.invoke(:render_sign_up_result, Result.new(result_status))

      assert_equal({ plain: result_status.to_s, status: http_status }, harness.rendered)
    end
  end

  test "requirement and checkpoint parameters accept direct and nested forms" do
    harness = Harness.new
    harness.params_value = { requirement: "birthdate", checkpoint_version: "3" }

    assert_equal "birthdate", harness.invoke(:sign_up_requirement_param)
    assert_equal "3", harness.invoke(:sign_up_checkpoint_version_param)

    harness.params_value = { sign_up: { requirement: "email", checkpoint_version: "4" } }

    assert_equal "email", harness.invoke(:sign_up_requirement_param)
    assert_equal "4", harness.invoke(:sign_up_checkpoint_version_param)
  end

  test "birthdate parameters accept explicit nested and split forms" do
    harness = Harness.new

    harness.params_value = { sign_up: { birthdate: "2000-01-02" } }

    assert_equal "2000-01-02", harness.invoke(:sign_up_birthdate_param)

    harness.params_value = { birth_year: 2001, birth_month: 2, birth_day: 3 }

    assert_equal "2001-02-03", harness.invoke(:sign_up_birthdate_param)

    harness.params_value = {}

    assert_nil harness.invoke(:sign_up_split_birthdate_param)
  end

  test "checkpoint validation accepts matching versions and rejects stale or malformed versions" do
    ticket = Struct.new(:checkpoint_version) do
      def has_attribute?(name) = name == :checkpoint_version
    end.new(7)
    harness = Harness.new
    harness.instance_variable_set(:@sign_up_ticket, ticket)

    harness.params_value = { checkpoint_version: "7" }

    assert harness.invoke(:validate_sign_up_checkpoint_version!)

    harness.params_value = { checkpoint_version: "6" }

    assert_not harness.invoke(:validate_sign_up_checkpoint_version!)
    assert_equal({ plain: "stale_checkpoint", status: :conflict }, harness.rendered)

    harness.params_value = { checkpoint_version: "invalid" }

    assert_not harness.invoke(:validate_sign_up_checkpoint_version!, json: true)
    assert_equal({ json: { error: "stale_checkpoint" }, status: :conflict }, harness.rendered)
  end

  test "invalid requirement and finalization contexts return nil" do
    harness = Harness.new
    harness.params_value = { requirement: "invalid" }
    harness.instance_variable_set(:@sign_up_ticket, Object.new)

    SignUpRequirementContext.stub(:build, ->(**) { raise ArgumentError, "invalid requirement" }) do
      assert_nil harness.invoke(:sign_up_requirement_context)
    end
    SignUpFinalizationContext.stub(:build, ->(**) { raise ArgumentError, "invalid finalization" }) do
      assert_nil harness.invoke(:sign_up_finalization_context)
    end
  end

  test "invalid requirement registries fail closed" do
    harness = Harness.new
    ticket = Struct.new(:completed_requirements).new([])
    harness.instance_variable_set(:@sign_up_ticket, ticket)

    SignUpRequirementRegistry.stub(:for_ticket, ->(*) { raise ArgumentError, "unknown surface" }) do
      assert_empty harness.invoke(:sign_up_missing_requirements)
      assert_not harness.invoke(:sign_up_requirement_cleared?, :birthdate)
    end
  end

  test "auth method and fallback paths cover unknown entry points and surfaces" do
    harness = Harness.new
    ticket = Struct.new(:entry_method).new("google")
    harness.instance_variable_set(:@sign_up_ticket, ticket)

    assert_equal "social", harness.invoke(:sign_up_auth_method)
    ticket.entry_method = "telephone"

    assert_equal "telephone", harness.invoke(:sign_up_auth_method)
    ticket.entry_method = nil

    assert_equal "sign_up", harness.invoke(:sign_up_auth_method)

    harness.surface = :org

    assert_equal "/", harness.invoke(:sign_up_restart_path)
    assert_raises(ArgumentError) { harness.invoke(:sign_up_recovery_passcode_config, :org) }
  end

  test "unknown ticket finalization and record mapping fail closed" do
    harness = Harness.new
    ticket = Object.new
    harness.instance_variable_set(:@sign_up_ticket, ticket)

    assert_equal :failed, harness.invoke(:finalize_sign_up_side_effect!)
    assert_equal ticket.class, harness.invoke(:sign_up_ticket_record_class)
    assert_nil harness.invoke(:sign_up_pending_actor_model)
    assert_nil harness.invoke(:sign_up_pending_telephone_model)
  end

  test "handoff responses cover json success pending and failure outcomes" do
    result_class =
      Struct.new(
        :success_value, :mfa_value, :limit_value, :redirect_to, :message, :status, :response_status,
      ) do
        def success? = success_value

        def mfa_required? = mfa_value

        def session_limit_pending? = limit_value
      end
    harness = Harness.new
    success = result_class.new(true, false, false, nil, nil, :ok, :ok)
    pending = result_class.new(false, true, false, "/mfa", nil, :mfa_required, :see_other)
    failed = result_class.new(false, false, false, nil, "failed", :failed, :unprocessable_content)

    harness.invoke(:redirect_after_sign_up_handoff!, success, json: true)

    assert_equal({ json: { status: "ok", redirect_url: "/next" }, status: :created }, harness.rendered)

    harness.invoke(:redirect_after_sign_up_handoff!, success)

    assert_equal({ sign_in_sequence: "handoff" }, harness.rendered)

    harness.invoke(:redirect_after_sign_up_handoff!, pending)

    assert_equal({ redirect_to: "/mfa" }, harness.rendered)

    harness.invoke(:redirect_after_sign_up_handoff!, failed)

    assert_equal({ plain: "failed", status: :unprocessable_content }, harness.rendered)
  end

  test "forbidden and failed finalization responses support html and json" do
    harness = Harness.new
    failure = Struct.new(:errors, :status).new(["first", "second"], :failed)

    harness.invoke(:render_sign_up_finalization_forbidden, json: true)

    assert_equal :forbidden, harness.rendered.fetch(:status)
    assert_includes harness.rendered.fetch(:json), :error

    harness.invoke(:render_sign_up_finalization_forbidden)

    assert_equal :forbidden, harness.rendered.fetch(:status)
    assert_includes harness.rendered, :plain

    harness.invoke(:render_sign_up_failure_result, failure, json: true)

    assert_equal :unprocessable_content, harness.rendered.fetch(:status)
    assert_match(/first.*second/, harness.rendered.dig(:json, :error))

    harness.invoke(:render_sign_up_failure_result, failure)

    assert_equal({ plain: "failed", status: :unprocessable_content }, harness.rendered)
  end
end
