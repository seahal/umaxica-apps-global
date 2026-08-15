# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class DashboardsController < ::Auth::Org::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private

      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        authorize!(current_operator, to: :show?)
        render inertia: true, props: dashboard_props
      end

      private

      def dashboard_props
        region = params[:ri]

        {
          title: "Dashboard",
          description: t("auth.org.dashboards.show.description"),
          sections: [
            {
              heading: "Primary links",
              items: [
                { label: "Root", href: auth_org_root_path(ri: region) },
                { label: "Sign in", href: auth_org_sign_in_path(ri: region) },
                { label: "Sign up", href: auth_org_sign_up_path(ri: region) },
                { label: "Settings", href: auth_org_settings_path(ri: region) },
                { label: "Logout", href: new_auth_org_sign_out_path(ri: region) },
              ],
            },
            {
              heading: "Ceremony links",
              items: [
                { label: "Sign-in guard", href: auth_org_sign_in_guard_path(ri: region) },
                { label: "Sign-in check", href: auth_org_sign_in_check_path(ri: region) },
                { label: "Sign-in challenge", href: auth_org_sign_in_challenge_path(ri: region) },
                # The selector has no direct dashboard route; it is reached through the guard
                # sequence, so it is a note rather than a link.
                { label: "Selector: handled by the sign-in guard sequence, no direct dashboard route", href: nil },
              ],
            },
          ],
        }
      end
    end
  end
end
