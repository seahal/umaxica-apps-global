# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Verification
      class SetupsController < ::Auth::Org::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!

        def new
          authorize!(current_operator, to: :show?)
          @pt = params[:pt].to_s.presence
          @pt_destination = setup_pt_path(@pt, root_path: auth_org_settings_path(ri: params[:ri]))
          @missing_methods = step_up_supported_methods - configured_step_up_methods

          if @missing_methods.empty?
            return safe_redirect_to(
              verification_redirect_path(pt: @pt),
              fallback: actor_root_path(ri: params[:ri]),
              status: :found,
            )
          end

          render inertia: true, props: setup_props
        end

        private

        # Only the methods the operator still has to configure are offered; a method already in
        # place is absent rather than rendered and disabled.
        def setup_props
          {
            title: t("sign.org.verification.setup.title"),
            description: t("sign.org.verification.setup.description"),
            back_link: if @pt_destination.present?
                         { label: t("actions.back"), href: @pt_destination }
                       end,
            methods: if @missing_methods.include?(:passkey)
                       [{
                         key: "passkey",
                         label: t("sign.org.verification.setup.methods.passkey"),
                         href: new_auth_org_settings_passkey_path(ri: params[:ri], pt: @pt),
                       }]
                     else
                       []
                     end,
          }
        end
      end
    end
  end
end
