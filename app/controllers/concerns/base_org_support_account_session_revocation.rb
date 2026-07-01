# typed: false
# frozen_string_literal: true

module BaseOrgSupportAccountSessionRevocation
  extend ActiveSupport::Concern

  def destroy
    purge
  end

  def purge
    render_result(AccountSessionRevocation.purge!(**revocation_attributes))
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  def emergency_revoke
    render_result(AccountSessionRevocation.emergency_revoke!(**revocation_attributes))
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  private

  attr_reader :target_account

  def require_session_revoke_step_up!
    require_step_up!(scope: "session_revoke_all")
  end

  def set_target_account
    # Account models expose public_id as their to_param, so the routed identifier is the public_id,
    # not the primary key. Resolve by public_id to match the URL helpers (find_by! keeps the 404
    # behavior for unknown targets).
    @target_account = self.class::TARGET_ACCOUNT_CLASS.find_by!(public_id: params.fetch(self.class::TARGET_PARAM))
  end

  def authorize_target_account!
    authorize!(target_account, to: :purge_sessions?)
  end

  def revocation_attributes
    {
      account: target_account,
      operator: current_operator,
      reason_code: params[:reason_code],
      reason_note: params[:reason_note],
      ticket_id: params[:ticket_id],
    }
  end

  def render_result(result)
    event = result.event
    render(
      json: {
        status: "ok",
        event_type: event.event_type,
        account_type: event.account_type,
        account_id: event.account_id,
        revoked_count: result.revoked_count,
        event_id: event.id,
      },
      status: :ok,
    )
  end
end
