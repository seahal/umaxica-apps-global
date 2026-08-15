# typed: false
# frozen_string_literal: true

module Base
  module App
    class DashboardsController < Base::App::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_client, to: :show?)
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

      def primary_links
        [
          { label: "Root", href: base_app_root_path(ri: params[:ri]) },
          { label: "Dashboard", href: base_app_dashboard_path(ri: params[:ri]) },
          { label: "Account", href: base_app_accounts_path(ri: params[:ri]) },
          { label: "Organization", href: base_app_organizations_path(ri: params[:ri]) },
          { label: "Avatar", href: base_app_avatars_path(ri: params[:ri]) },
          { label: "Switcher", href: base_app_switcher_path(ri: params[:ri]) },
          { label: "Identity", href: base_app_identity_path(ri: params[:ri]) },
          { label: "Selector", href: base_app_selector_path(ri: params[:ri]) },
          { label: "Logout", href: new_base_app_sign_out_path(ri: params[:ri]) },
        ]
      end

      def protocol_links
        [
          {
            label: "Authorize (sign in)",
            href: base_app_oidc_authorization_path(ri: params[:ri], screen_hint: "signin"),
          },
          {
            label: "Authorize (sign up)",
            href: base_app_oidc_authorization_path(ri: params[:ri], screen_hint: "signup"),
          },
          { label: "OIDC discovery", href: base_app_well_known_openid_configuration_path },
          { label: "JWKS", href: base_app_well_known_jwks_path },
          { label: "UserInfo", href: base_app_oauth_userinfo_path },
        ]
      end
    end
  end
end
