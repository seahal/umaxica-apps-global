# typed: false
# frozen_string_literal: true

# Shared behavior for sign-in check and check-cancellation controllers on the org surface.
# Include this instead of inheriting from Sign::Org::Sign::In::ChecksController.
module SignOrgInCheckControllerSupport
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
      sign_org_sign_in_check_path(pt: signed_pt_param, ri: current_region_identifier),
      fallback: sign_org_sign_in_check_path(ri: current_region_identifier),
    )
  end

  def destroy
    pt_param = signed_pt_param
    consume_bulletin!
    redirect_after_checkpoint_sequence!(pt: pt_param)
  end

  private

  def sign_in_sequence_required_for_participant?(participant)
    participant.to_sym == :checkpoint
  end

  def sign_in_sequence_surface
    :org
  end

  def guard_timeout
    return unless bulletin_expired?

    render plain: I18n.t("sign.org.in.bulletins.timeout"), status: :request_timeout
  end
end
