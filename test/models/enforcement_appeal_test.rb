# typed: false
# frozen_string_literal: true

require "test_helper"

class EnforcementAppealTest < ActiveSupport::TestCase
  test "app appeal requires a fixed reason category and a bounded statement" do
    appeal = AppEnforcementAppeal.new(
      enforcement_case: AppEnforcementCase.new(
        kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
        release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
        principal_public_id: "client-standing-test", applied_by_operator_public_id: "operator-standing-test",
      ),
      reason_code: "incorrect_decision",
      statement: "The enforcement decision is incorrect.",
      submitted_at: Time.current,
      state: "submitted",
    )

    assert_predicate appeal, :valid?
  end

  test "appeal rejects an unsupported reason category" do
    appeal = AppEnforcementAppeal.new(
      enforcement_case: AppEnforcementCase.new(
        kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
        release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
        principal_public_id: "client-standing-test", applied_by_operator_public_id: "operator-standing-test",
      ),
      reason_code: "free_form_reason",
      statement: "Please reconsider this decision.",
      submitted_at: Time.current,
      state: "submitted",
    )

    assert_not_predicate appeal, :valid?
    assert_equal :inclusion, appeal.errors.details.fetch(:reason_code).fetch(0).fetch(:error)
  end

  test "appeal redaction clears the stored statement without rewriting the decision" do
    enforcement_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: "client-standing-redaction", applied_by_operator_public_id: "operator-standing-test",
    )
    appeal = AppEnforcementAppeal.create!(
      enforcement_case: enforcement_case,
      reason_code: "new_information",
      statement: "Sensitive detail that must not survive account erasure.",
      submitted_at: Time.current,
      state: "submitted",
    )

    appeal.redact!

    assert_equal "redacted", appeal.state
    assert_nil appeal.statement
    assert_not_nil appeal.redacted_at
  end

  test "appeal resolution requires a reviewer distinct from the Case operators" do
    enforcement_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: "client-standing-review", applied_by_operator_public_id: "operator-applying",
      approved_by_operator_public_id: "operator-approving",
    )
    appeal = AppEnforcementAppeal.create!(
      enforcement_case: enforcement_case,
      reason_code: "incorrect_decision",
      statement: "Please review the decision.",
      submitted_at: Time.current,
      state: "submitted",
    )

    error =
      assert_raises(EnforcementAppeal::ReviewerSeparationError) do
        appeal.resolve!(reviewer_operator_public_id: "operator-applying", resolution_code: "rejected")
      end

    assert_match(/must differ/, error.message)
    assert_equal "submitted", appeal.reload.state
  end

  test "a rejected appeal records its reviewer and immutable resolution" do
    enforcement_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: "client-standing-rejected", applied_by_operator_public_id: "operator-applying",
    )
    appeal = AppEnforcementAppeal.create!(
      enforcement_case: enforcement_case,
      reason_code: "new_information",
      statement: "I have new information.",
      submitted_at: Time.current,
      state: "submitted",
    )

    appeal.resolve!(reviewer_operator_public_id: "operator-reviewing", resolution_code: "rejected")

    assert_equal "rejected", appeal.state
    assert_equal "operator-reviewing", appeal.reviewer_operator_public_id
    assert_equal "rejected", appeal.resolution_code
    assert_not_nil appeal.reviewed_at
  end
end
