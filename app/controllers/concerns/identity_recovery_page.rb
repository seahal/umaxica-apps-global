# typed: false
# frozen_string_literal: true

# Serializes the enforcement recovery screen.
#
# Two controllers answer with the same page: the recovery status action and the appeal submission
# failure path, so the prop construction lives here rather than being duplicated. Everything the
# page shows is resolved on the server: labels, the appeal reason choices, and the URLs each form
# posts to.
module IdentityRecoveryPage
  extend ActiveSupport::Concern

  COMPONENT = "base/app/identity/recoveries/show"

  private

  def render_identity_recovery(enforcement_cases:, appeal_error: nil, status: :ok)
    render inertia: COMPONENT,
           props: identity_recovery_props(enforcement_cases: enforcement_cases, appeal_error: appeal_error),
           status: status
  end

  def identity_recovery_props(enforcement_cases:, appeal_error: nil)
    {
      title: "Account recovery",
      description: t("base.app.identity.recoveries.show.description"),
      appeal_error: appeal_error,
      enforcement_cases: enforcement_cases.map { |enforcement_case| serialize_recovery_case(enforcement_case) },
    }
  end

  def serialize_recovery_case(enforcement_case)
    {
      public_id: enforcement_case.public_id,
      kind_label: enforcement_case.kind.to_s.humanize,
      restore: {
        url: base_app_identity_recovery_completion_path,
        submit_label: "Restore access",
      },
      appeal: appealable_recovery_case?(enforcement_case) ? recovery_appeal_form_props : nil,
    }
  end

  def appealable_recovery_case?(enforcement_case)
    enforcement_case.kind != "method_protection" && enforcement_case.appeal.blank?
  end

  def recovery_appeal_form_props
    {
      url: base_app_identity_recovery_appeals_path,
      reason_label: "Appeal reason",
      reason_codes: EnforcementAppeal::REASON_CODES.map { |code| { label: code, value: code } },
      statement_label: "Appeal statement",
      statement_max_length: EnforcementAppeal::MAXIMUM_STATEMENT_LENGTH,
      submit_label: "Submit appeal",
    }
  end
end
