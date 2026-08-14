# typed: false
# frozen_string_literal: true

module Base
  module Org
    class DashboardsController < Base::Org::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_operator, to: :show?)
        render inertia: true, props: show_page_props
      end

      private

      def show_page_props
        {
          title: "Dashboard",
          description: "Signed in",
          sections: [
            { heading: "Primary links", items: primary_links },
            { heading: "Protocol links", items: protocol_links },
          ],
        }
      end

      # The org surface has no switcher, so that entry is absent rather than rendered and hidden.
      def primary_links
        [
          { label: "Root", href: base_org_root_path(ri: params[:ri]) },
          { label: "Dashboard", href: base_org_dashboard_path(ri: params[:ri]) },
          { label: "Account", href: base_org_accounts_path(ri: params[:ri]) },
          { label: "Organization", href: base_org_organizations_path(ri: params[:ri]) },
          { label: "Avatar", href: base_org_avatar_path(ri: params[:ri]) },
          { label: "Identity", href: base_org_identity_path(ri: params[:ri]) },
          { label: "Selector", href: base_org_selector_path(ri: params[:ri]) },
          { label: "Logout", href: new_base_org_sign_out_path(ri: params[:ri]) },
        ]
      end

      def protocol_links
        [
          {
            label: "Authorize (sign in)",
            href: base_org_oidc_authorization_path(ri: params[:ri], screen_hint: "signin"),
          },
          {
            label: "Authorize (sign up)",
            href: base_org_oidc_authorization_path(ri: params[:ri], screen_hint: "signup"),
          },
          { label: "OIDC discovery", href: base_org_well_known_openid_configuration_path },
          { label: "JWKS", href: base_org_well_known_jwks_path },
          { label: "UserInfo", href: base_org_oauth_userinfo_path },
        ]
      end
    end
  end
end
