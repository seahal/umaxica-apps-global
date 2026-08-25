# typed: false
# frozen_string_literal: true

module Base
  module Org
    class RootsController < Base::Org::ApplicationController
      include ::RegionalRootRedirect
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      redirect_root_to_regional_host(surface: :org)

      def index
        redirect_to(base_org_dashboard_path(ri: params[:ri])) and return if logged_in?

        render inertia: true, props: root_landing_props
      end

      private

      def root_landing_props
        {
          title: "Base Org",
          heading: "Base Org",
          description: t("landing.thin_endpoint"),
          sign_up: {
            label: "Sign up",
            href: base_org_oidc_authorization_path(ri: params[:ri]),
          },
        }
      end
    end
  end
end
