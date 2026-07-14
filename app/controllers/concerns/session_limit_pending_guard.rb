# typed: false
# frozen_string_literal: true

module SessionLimitPendingGuard
  extend ActiveSupport::Concern

  included do
    before_action :redirect_pending_session_limit
  end

  private

  def redirect_pending_session_limit
    return unless respond_to?(:session_limit_pending?) && session_limit_pending?
    return if pending_allowed_action?

    flash[:alert] = t("session_limit.pending.message", default: "セッション整理が必要です。既存のセッションを無効化してください。")
    redirect_to(pending_session_limit_redirect_path)
  end

  def pending_allowed_action?
    pending_allowed_actions.any?("#{params[:controller]}##{params[:action]}")
  end

  def pending_allowed_actions
    []
  end

  def pending_session_limit_redirect_path
    raise NotImplementedError, "Define pending_session_limit_redirect_path in including controller"
  end
end
