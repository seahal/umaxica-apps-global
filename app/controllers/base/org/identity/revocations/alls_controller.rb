# typed: false
# frozen_string_literal: true

class Base::Org::Identity::Revocations::AllsController < ::Base::Org::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_operator!
  step_up only: %i(create destroy)

  def create
    logout_all_sessions_for!(resource: current_operator, reason: "settings.session.revoke_all")
    redirect_to(auth_org_sign_out_path(ri: params[:ri]), status: :see_other)
  end
  alias_method :destroy, :create

  private

  def verification_scope
    "session_revoke_all"
  end
end
