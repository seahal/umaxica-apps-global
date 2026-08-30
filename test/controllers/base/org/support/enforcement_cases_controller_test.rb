# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Support::EnforcementCasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "www.umaxica.org")
    @operator = operators(:one)
    @approver = operators(:two)
    @operator_token = OperatorToken.create!(
      staff_id: @operator.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    @approver_token = OperatorToken.create!(
      staff_id: @approver.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
  end

  test "operator creates a cooldown case with no approval required and it applies immediately" do
    client = clients(:one)
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_apply")

    post(
      base_org_support_app_enforcement_cases_url(host: @host),
      params: {
        enforcement_case: {
          kind: "cooldown",
          duration_mode: "timed",
          visibility: "visible",
          release_mode: "automatic",
          effective_at: Time.current,
          expires_at: 1.day.from_now,
          reason_code: "abuse",
          principal_public_id: client.public_id,
        },
      },
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :created
    body = response.parsed_body

    assert_equal "active", body.fetch("state")
    assert_equal client.public_id, body.fetch("principal_public_id")
  end

  test "a hidden permanent_ban requires approval and does not apply on create" do
    client = clients(:one)
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_apply")

    post(
      base_org_support_app_enforcement_cases_url(host: @host),
      params: {
        enforcement_case: {
          kind: "permanent_ban",
          duration_mode: "permanent",
          visibility: "hidden",
          release_mode: "break_glass_only",
          effective_at: Time.current,
          reason_code: "abuse",
          principal_public_id: client.public_id,
        },
      },
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :accepted
    body = response.parsed_body

    assert_equal "pending_approval", body.fetch("state")
    the_case = AppEnforcementCase.find_by!(public_id: body.fetch("public_id"))

    assert_nil the_case.approved_by_operator_public_id
    assert_not_predicate the_case.identifier_effects, :exists?
  end

  test "a second operator approves a pending case, attaches the effect, and it applies" do
    client = clients(:one)
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "hidden",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: @operator.public_id,
    )
    mark_token_step_up_satisfied_for_test(@approver_token, scope: "enforcement_case_approve")

    post(
      base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
      params: {
        principal_effect: { access_blocking: true },
      },
      headers: as_staff_headers(@approver, host: @host, session_public_id: @approver_token.public_id),
      as: :json,
    )

    assert_response :ok
    the_case.reload
    client.reload

    assert_equal "active", the_case.state
    assert_equal @approver.public_id, the_case.approved_by_operator_public_id
    assert_predicate client, :admin_locked?
  end

  test "the applying operator cannot approve their own case" do
    client = clients(:one)
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "hidden",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: @operator.public_id,
    )
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_approve")

    post(
      base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
      params: {},
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :forbidden
  end

  test "an operator releases an active case, ending it" do
    client = clients(:one)
    the_case = AppEnforcementCase.new(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: @operator.public_id,
    )
    the_case.build_principal_effect(principal_public_id: client.public_id, access_blocking: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(enforcement_case: the_case)
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_release")

    post(
      base_org_support_app_enforcement_case_release_url(the_case.public_id, host: @host),
      params: { reason: "revoked" },
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :ok
    the_case.reload
    client.reload

    assert_predicate the_case.ended_at, :present?
    assert_not_predicate client, :admin_locked?
  end

  test "a separate operator can reject an appeal through the review resource" do
    client = clients(:one)
    the_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: client.public_id, applied_by_operator_public_id: @operator.public_id,
    )
    appeal = AppEnforcementAppeal.create!(
      # rubocop:disable I18n/RailsI18n/DecorateString -- appeal statements are stored user content, not UI copy
      enforcement_case: the_case, reason_code: "incorrect_decision", statement: "Please review this decision.",
      # rubocop:enable I18n/RailsI18n/DecorateString
      submitted_at: Time.current,
    )
    mark_token_step_up_satisfied_for_test(@approver_token, scope: "enforcement_case_review_appeal")

    post(
      base_org_support_app_enforcement_case_appeal_review_url(the_case.public_id, host: @host),
      params: { resolution_code: "rejected" },
      headers: as_staff_headers(@approver, host: @host, session_public_id: @approver_token.public_id),
      as: :json,
    )

    assert_response :ok
    assert_equal "rejected", appeal.reload.state
    assert_equal @approver.public_id, appeal.reviewer_operator_public_id
  end

  test "index scopes strictly to the app realm and never returns com or org cases" do
    app_client = clients(:one)
    com_visitor = visitors(:reserved_visitor)

    app_case = AppEnforcementCase.create!(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: app_client.public_id, applied_by_operator_public_id: @operator.public_id,
    )
    ComEnforcementCase.create!(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: com_visitor.public_id, applied_by_operator_public_id: @operator.public_id,
    )
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "enforcement_case_apply")

    get(
      base_org_support_app_enforcement_cases_url(host: @host, principal_public_id: app_client.public_id),
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :ok
    body = response.parsed_body
    public_ids = body.fetch("enforcement_cases").map { |c| c.fetch("public_id") }

    assert_includes public_ids, app_case.public_id
  end

  private

  # as_staff_headers / host_headers come from the globally-included
  # AuthenticationHarness (test/test_helper.rb) -- it mints a real JWT access
  # cookie for the operator, unlike the raw X-TEST-* headers some older test
  # files shadow it with locally.

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end
end
