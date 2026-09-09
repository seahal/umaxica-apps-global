# typed: false
# frozen_string_literal: true

# Refuses to start a sign-in ceremony for a browser that is already
# authenticated, and says why.
#
# There is no supported transition between the Normal and Emergency
# authentication contexts inside a session. A Normal session cannot be
# downgraded into Restricted Mode in place, and an Emergency session cannot be
# upgraded into a Normal one -- not by completing Entra, not by re-running the
# Passkey or Secret ceremony, not by Step-Up, and not by any token rotation or
# session renewal. Changing mode means signing out and signing in again.
#
# The refusal itself is the surface's ordinary guest-only rejection: this
# concern only replaces the response so that it names the sign-out ceremony
# instead of bouncing the operator to the dashboard, where nothing would
# explain why their request did nothing. It installs no callbacks -- it
# overrides the guest-only response hooks the authentication layer already
# calls.
module AuthenticationModeSwitchGuard
  extend ActiveSupport::Concern

  private

  def handle_guest_only_json(_options)
    render json: {
      error: authentication_mode_switch_message,
      sign_out_url: authentication_mode_switch_sign_out_url,
    }, status: :forbidden
  end

  def handle_guest_only_html(_options)
    render plain: authentication_mode_switch_message, status: :forbidden
  end

  # Reached for non-GET, non-JSON guest-only rejections. Same answer: the
  # request is refused, and the way forward is sign-out.
  def handle_guest_only_with_status_checks(options)
    return handle_guest_only_json(options) if request.format.json?

    handle_guest_only_html(options)
  end

  def authentication_mode_switch_message
    I18n.t(
      "sign.org.authentication.mode_switch.sign_out_required",
      sign_out_url: authentication_mode_switch_sign_out_url,
    )
  end

  def authentication_mode_switch_sign_out_url
    new_auth_org_sign_out_path(ri: current_region_identifier)
  end
end
