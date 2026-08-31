# typed: false
# frozen_string_literal: true

require "test_helper"

# The corporate recovery screen is built server-side: the labels, the appeal reason
# choices and the URL each form posts to. Two controllers render it, so the prop
# construction lives in the concern. An appeal is only offered for a case that can
# be appealed and has not been appealed already.
class ComIdentityRecoveryPageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include ComIdentityRecoveryPage

    attr_accessor :rendered

    def t(key, **) = "t:#{key}"

    def base_com_identity_recovery_completion_path = "/identity/recovery/completion"

    def base_com_identity_recovery_appeals_path = "/identity/recovery/appeals"

    def render(**options) = @rendered = options

    def invoke(name, ...) = send(name, ...)
  end

  EnforcementCase = Struct.new(:public_id, :kind, :appeal)

  setup { @harness = Harness.new }

  test "an appealable case carries the appeal form, a method-protection case does not" do
    appealable = EnforcementCase.new("case-1", "abuse", nil)
    method_protection = EnforcementCase.new("case-2", "method_protection", nil)
    already_appealed = EnforcementCase.new("case-3", "abuse", :an_appeal)

    assert @harness.invoke(:appealable_com_recovery_case?, appealable)
    assert_not @harness.invoke(:appealable_com_recovery_case?, method_protection)
    assert_not @harness.invoke(:appealable_com_recovery_case?, already_appealed)
  end

  test "a serialized case names its restore form and humanises its kind" do
    row = @harness.invoke(:serialize_com_recovery_case, EnforcementCase.new("case-1", "method_protection", nil))

    assert_equal "case-1", row.fetch(:public_id)
    assert_equal "Method protection", row.fetch(:kind_label)
    assert_equal "/identity/recovery/completion", row.fetch(:restore).fetch(:url)
    assert_nil row.fetch(:appeal), "a method-protection case is not appealable"
  end

  test "the appeal form offers every reason code and caps the statement" do
    form = @harness.invoke(:com_recovery_appeal_form_props)

    assert_equal "/identity/recovery/appeals", form.fetch(:url)
    assert_equal "appeal", form.fetch(:scope)
    assert_equal EnforcementAppeal::REASON_CODES.size, form.fetch(:reason_codes).size
    assert_equal EnforcementAppeal::MAXIMUM_STATEMENT_LENGTH, form.fetch(:statement_max_length)
  end

  test "the page lists every case it was given and carries an appeal error through" do
    cases = [EnforcementCase.new("case-1", "abuse", nil), EnforcementCase.new("case-2", "abuse", nil)]

    props = @harness.invoke(:com_identity_recovery_props, enforcement_cases: cases, appeal_error: "too long")

    assert_equal "too long", props.fetch(:appeal_error)
    assert_equal %w(case-1 case-2), props.fetch(:enforcement_cases).map { |c| c.fetch(:public_id) }

    @harness.invoke(:render_com_identity_recovery, enforcement_cases: cases, status: :unprocessable_content)

    assert_equal ComIdentityRecoveryPage::COMPONENT, @harness.rendered.fetch(:inertia)
    assert_equal :unprocessable_content, @harness.rendered.fetch(:status)
  end
end
