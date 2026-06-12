# typed: false
# frozen_string_literal: true

module SignOrgVerificationBase
  extend ActiveSupport::Concern

  STEP_UP_TTL = 15.minutes

  ALLOWED_SCOPES = StepUpScopeCatalog::ORG

  private

  def verification_params
    params.fetch(:verification, {}).permit(:code, :challenge_id, :credential_json, :scope, :pt)
  end

  def verification_unavailable_redirect_path
    sign_org_verification_path(ri: params[:ri])
  end

  def step_up_session_model = OperatorStepUpSession

  def step_up_session_token_foreign_key = :staff_token_id
end
