# typed: false
# frozen_string_literal: true

module Auth
  module Com
    class DashboardsController < ::Auth::Com::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private

      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def show
        authorize!(current_visitor, to: :show?)
        render inertia: true, props: dashboard_props
      end

      private

      def dashboard_props
        region = params[:ri]

        {
          title: "Dashboard",
          description: "Sign com signed-in landing.",
          sections: [
            {
              heading: "Primary links",
              items: [
                { label: "Root", href: auth_com_root_path(ri: region) },
                { label: "Sign in", href: auth_com_sign_in_path(ri: region) },
                { label: "Sign up", href: auth_com_sign_up_path(ri: region) },
                { label: "Settings", href: auth_com_settings_path(ri: region) },
                { label: "Logout", href: new_auth_com_sign_out_path(ri: region) },
              ],
            },
            {
              heading: "Ceremony links",
              items: [
                { label: "Sign-in guard", href: auth_com_sign_in_guard_path(ri: region) },
                { label: "Sign-in check", href: auth_com_sign_in_check_path(ri: region) },
                { label: "Sign-in challenge", href: auth_com_sign_in_challenge_path(ri: region) },
                { label: "Selector: handled by the sign-in guard sequence, no direct dashboard route", href: nil },
              ],
            },
          ],
        }
      end
    end
  end
end
