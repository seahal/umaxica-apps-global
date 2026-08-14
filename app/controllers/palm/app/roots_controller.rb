# typed: false
# frozen_string_literal: true

module Palm
  module App
    class RootsController < Palm::App::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :bare

      def index
        render inertia: true, props: root_landing_props
      end

      private

      def root_landing_props
        {
          title: nil,
          heading: "Palm App",
          description: t("palm.app.roots.message"),
          sign_up: nil,
          links: [
            { label: "Sign up on iOS", href: palm_app_oidc_authorization_path(client_id: "app-ios-rp") },
            { label: "Sign up on Android", href: palm_app_oidc_authorization_path(client_id: "app-android-rp") },
          ],
        }
      end
    end
  end
end
