# typed: false
# frozen_string_literal: true

module Auth
  module Com
    class RootsController < ::Auth::Com::ApplicationController
      include ::RootSignInRedirect
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      redirect_root_to_sign_in { |region| auth_com_sign_in_path(ri: region) }

      def index
        if logged_in?
          redirect_to(after_login_path, allow_other_host: after_login_allows_other_host?)
          return
        end

        render inertia: true, props: root_landing_props
      end

      private

      # The heading stays the surface name; the body is the same landing sentence the other
      # surfaces already answer with, so it uses the shared key rather than a second English copy.
      def root_landing_props
        {
          title: "Sign Com",
          heading: "Sign Com",
          description: t("landing.thin_endpoint"),
          sign_up: nil,
        }
      end
    end
  end
end
