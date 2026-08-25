# typed: false
# frozen_string_literal: true

# Installs the `sign_up_suspended_{surface}` kill switch on a registration entry
# point.
#
# Including controllers declare their trust boundary with `sign_up_surface`
# (the existing per-controller convention, as in
# Auth::App::Sign::Up::Guard::BaseController) rather than deriving it from the
# request host: the gate must match the routed surface, not whatever host label
# a request happens to carry.
#
# The response re-renders the surface's own sign-up page with a 503 and
# `@sign_up_available = false`, following the `@provider_available` pattern in
# Auth::Org::Social::SessionsController#create. No flash, no new exception
# class, no middleware.
#
# The `before_action` is declared by each including controller rather than
# installed here: the social ceremony entry shares a controller with sign-in and
# must run the check only on the sign-up branch (see SocialCeremonyEntry).
module SignUpSuspensionGuard
  extend ActiveSupport::Concern

  private

  # @return [Boolean] true when the request was answered with the suspension
  #   response, so callers outside the `before_action` chain can stop.
  def reject_suspended_sign_up!
    # An authenticated request is not a registration: the sign-up entry points
    # redirect or reject logged-in users on their own terms, and closing new
    # registration must not change what an existing user sees.
    return false if respond_to?(:logged_in?, true) && logged_in?
    return false unless SignUpSuspension.suspended?(sign_up_surface)

    Rails.logger.warn(
      JitLogEvent.format("sign_up.suspended", surface: sign_up_surface.to_s),
    )
    @sign_up_available = false
    render_suspended_sign_up!
    true
  end

  # The status and the "re-render the sign-up entry page" shape are fixed; how that page is
  # rendered is not. A surface whose entry page is an Inertia component overrides this to render
  # the component with the same status, rather than an ERB template that no longer exists.
  def render_suspended_sign_up!
    render(suspended_sign_up_template, status: :service_unavailable)
  end

  def suspended_sign_up_template
    "auth/#{sign_up_surface}/sign_ups/new"
  end
end
