# typed: false
# frozen_string_literal: true

module Auth
  module App
    class RootsController < ::Auth::App::ApplicationController
      include ::RootSignInRedirect
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      redirect_root_to_sign_in { |region| auth_app_sign_in_path(ri: region) }

      def index
        if logged_in?
          redirect_to(after_login_path, allow_other_host: after_login_allows_other_host?) and return
        end

        render inertia: true, props: root_landing_props
      end

      private

      def root_landing_props
        {
          title: "Sign App",
          heading: "Sign App",
          description: t("landing.thin_endpoint"),
          sign_up: nil,
        }
      end
    end
  end
end
