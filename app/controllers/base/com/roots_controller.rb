# typed: false
# frozen_string_literal: true

module Base
  module Com
    class RootsController < Base::Com::ApplicationController
      include ::RegionalRootRedirect
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      redirect_root_to_regional_host(surface: :com)

      def index
        redirect_to(base_com_dashboard_path(ri: params[:ri])) and return if logged_in?

        render inertia: true, props: root_landing_props
      end

      private

      def root_landing_props
        {
          title: "Base Com",
          heading: "Base Com",
          description: t("landing.thin_endpoint"),
          sign_up: {
            label: "Sign up",
            href: base_com_oidc_authorization_path(ri: params[:ri]),
          },
        }
      end
    end
  end
end
