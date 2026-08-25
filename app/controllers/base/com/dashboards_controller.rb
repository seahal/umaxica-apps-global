# typed: false
# frozen_string_literal: true

module Base
  module Com
    class DashboardsController < Base::Com::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_visitor, to: :show?)
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

      # The com surface has neither an avatar nor a switcher, so those entries are absent rather
      # than rendered and hidden.
      def primary_links
        [
          { label: "Root", href: base_com_root_path(ri: params[:ri]) },
          { label: "Dashboard", href: base_com_dashboard_path(ri: params[:ri]) },
          { label: "Account", href: base_com_accounts_path(ri: params[:ri]) },
          { label: "Organization", href: base_com_organizations_path(ri: params[:ri]) },
          { label: "Identity", href: base_com_identity_path(ri: params[:ri]) },
          { label: "Selector", href: base_com_selector_path(ri: params[:ri]) },
          { label: "Logout", href: new_base_com_sign_out_path(ri: params[:ri]) },
        ]
      end

      def protocol_links
        [
          {
            label: "Authorize (sign in)",
            href: base_com_oidc_authorization_path(ri: params[:ri], screen_hint: "signin"),
          },
          {
            label: "Authorize (sign up)",
            href: base_com_oidc_authorization_path(ri: params[:ri], screen_hint: "signup"),
          },
          { label: "OIDC discovery", href: base_com_well_known_openid_configuration_path },
          { label: "JWKS", href: base_com_well_known_jwks_path },
          { label: "UserInfo", href: base_com_oauth_userinfo_path },
        ]
      end
    end
  end
end
