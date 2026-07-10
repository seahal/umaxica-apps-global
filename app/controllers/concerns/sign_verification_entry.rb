# typed: false
# frozen_string_literal: true

module SignVerificationEntry
  extend ActiveSupport::Concern

  def show
    pt_param = params[:pt].presence

    if params[:scope].present? && pt_param.present?
      start_step_up_session!(scope: params[:scope], pt_param: pt_param)
    end

    if current_step_up_session.present?
      return unless require_step_up_session!
    elsif verification_recent_for_get?(scope: @actor_token&.last_step_up_scope)
      flash.now[:notice] = I18n.t(verification_success_notice_key)
    end

    @available_methods = available_step_up_methods
  rescue ActionController::BadRequest
    clear_step_up_state! if respond_to?(:clear_step_up_state!, true)
    redirect_to(
      verification_invalid_request_redirect_path(ri: params[:ri]),
      alert: I18n.t("auth.step_up.invalid_request"),
    )
  end

  private

  def verification_success_notice_key
    raise NotImplementedError, "#{self.class} must define #verification_success_notice_key"
  end

  def verification_invalid_request_redirect_path(ri:)
    raise NotImplementedError, "#{self.class} must define #verification_invalid_request_redirect_path"
  end
end
