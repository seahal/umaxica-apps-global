# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class RootsController < ::Auth::Org::ApplicationController
      include ::RootSignInRedirect
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      redirect_root_to_sign_in { |region| auth_org_sign_in_path(ri: region) }

      def index
        return redirect_to(after_login_path, allow_other_host: after_login_allows_other_host?) if logged_in?

        render inertia: true, props: root_landing_props
      end

      private

      def root_landing_props
        {
          title: "Sign Org",
          heading: "Sign Org",
          description: "Thin landing endpoint.",
          # The org root is staff-only and has no self-service registration to offer.
          sign_up: nil,
        }
      end
    end
  end
end
