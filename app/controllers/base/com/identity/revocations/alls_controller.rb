# typed: false
# frozen_string_literal: true

class Base::Com::Identity::Revocations::AllsController < ::Base::Com::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_visitor!
  step_up only: %i(create destroy)

  def create
    authorize!(current_visitor, to: :revoke_all?)
    logout_all_sessions_for!(resource: current_visitor, reason: "settings.session.revoke_all")
    redirect_to(auth_com_sign_out_path(ri: params[:ri]), status: :see_other)
  end
  alias_method :destroy, :create

  private

  def verification_scope
    "session_revoke_all"
  end
end
