# typed: false
# frozen_string_literal: true

# Shared behavior for sign-in check and check-cancellation controllers on the com surface.
# Include this instead of inheriting from Sign::Com::Sign::In::ChecksController.
module SignComInCheckControllerSupport
  extend ActiveSupport::Concern

  def show
    @bulletin = current_bulletin
  end

  def update
    return unless require_sign_in_sequence_participant!(
      participant: :checkpoint,
      policy_rule: :update_checkpoint?,
    )

    refresh_bulletin_dimension!
    safe_redirect_to(
      auth_com_sign_in_check_path(pt: signed_pt_param, ri: current_region_identifier),
      fallback: auth_com_sign_in_check_path(ri: current_region_identifier),
    )
  end

  def destroy
    pt_param = signed_pt_param
    consume_bulletin!
    return head :no_content if request.format.json?

    redirect_after_checkpoint_sequence!(pt: pt_param, status: :see_other)
  end

  private

  def sign_in_sequence_required_for_participant?(participant)
    participant.to_sym == :checkpoint
  end

  def sign_in_sequence_surface
    :com
  end

  def guard_timeout
    return unless bulletin_expired?

    render plain: I18n.t("sign.com.in.bulletins.timeout"), status: :request_timeout
  end
end
