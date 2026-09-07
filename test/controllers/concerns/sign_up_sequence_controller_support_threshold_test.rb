# typed: false
# frozen_string_literal: true

require_relative "sign_up_sequence_controller_support_extra_coverage_test"

class SignUpSequenceControllerSupportThresholdTest < ActiveSupport::TestCase
  def harness
    SignUpSequenceControllerSupportExtraCoverageTest::Harness.new
  end

  test "render result maps every protocol status to HTTP status" do
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
    expected.each do |status, http|
      h = harness
      h.send(:render_sign_up_result, Struct.new(:status).new(status))

      assert_equal http, h.rendered.last[:status]
    end
  end

  test "sign-up parameter and ticket helpers cover blank and nested values" do
    h = harness

    assert_nil h.send(:sign_up_ticket_public_id)
    h.session[:auth_app_up_sequence_id] = "cycle-1"

    assert_equal "cycle-1", h.send(:sign_up_ticket_public_id)
    assert_equal "", h.send(:sign_up_requirement_param)
    h.params_hash = { sign_up: { requirement: "birthdate" } }

    assert_equal "birthdate", h.send(:sign_up_requirement_param)
    h.params_hash = {}

    assert_nil h.send(:sign_up_requirement_context)
  end

  test "age restricted rendering supports app and com and rejects unknown surfaces" do
    %i(app com).each do |surface|
      h = harness
      h.surface_value = surface
      h.send(:render_sign_up_age_restricted)

      assert_equal :ok, h.rendered.last[:status]
      assert_equal "no-store, private", h.response.headers["Cache-Control"]
    end
    h = harness
    h.surface_value = :org
    assert_raises(ArgumentError) { h.send(:render_sign_up_age_restricted) }
  end

  test "birthdate persistence short circuits nonbirth and invalid checkpoints" do
    h = harness

    assert h.send(:persist_sign_up_birthdate_requirement)
    h.params_hash = { requirement: "birthdate" }
    h.define_singleton_method(:validate_sign_up_checkpoint_version!) { false }

    assert_not h.send(:persist_sign_up_birthdate_requirement)
    h.define_singleton_method(:validate_sign_up_checkpoint_version!) { true }

    assert_not h.send(:persist_sign_up_birthdate_requirement)
    assert h.rendered
  end

  test "authorization helpers stop for performed and denied contexts" do
    h = harness
    h.performed_value = true

    assert_nil h.send(:authorize_sign_up_participant!, :show?)
    h.performed_value = false
    h.allowed_value = false
    h.send(:authorize_sign_up_participant!, :show?)

    assert_equal :forbidden, h.rendered.last[:status]
    h.rendered = nil
    h.params_hash = {}
    h.allowed_value = false
    h.send(:authorize_sign_up_requirement_or_cleared_continue!, :show?)

    assert_equal :forbidden, h.rendered.last[:status]
  end
end
