# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class SecretsController < ::Base::Com::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        REVEAL_PURPOSE = "visitor.recovery_secret_credential"

        before_action :authenticate_visitor!
        before_action :authorize_secrets!, only: :show

        def show
          reveal = IdentityOneTimeReveal.consume!(
            actor: current_visitor,
            session_nonce: current_visitor.public_id,
            token: params[:token],
            purpose: REVEAL_PURPOSE,
          )

          if reveal
            @recovery_passcodes = Array(reveal.value).map(&:to_s)
            @back_to_settings_url = base_com_identity_url(ri: params[:ri])
          else
            @missing_recovery_passcodes = true
            @back_to_settings_url = base_com_identity_url(ri: params[:ri])
          end

          render inertia: true, props: show_page_props
        end

        private

        # The passcodes are the one-time reveal this action just consumed: the ERB printed them and
        # so does the page. They are sent to the owner who redeemed the reveal token and nowhere else.
        def show_page_props
          {
            title: t("sign.recovery_passcodes.show.title"),
            description: t("sign.recovery_passcodes.show.description"),
            one_time_notice: t("sign.recovery_passcodes.show.one_time_notice"),
            inventory_notice: t("sign.recovery_passcodes.show.inventory_notice"),
            missing_message: t("sign.recovery_passcodes.show.missing"),
            passcodes: Array(@recovery_passcodes),
            back_link: {
              label: t("sign.recovery_passcodes.show.back_to_settings"),
              href: @back_to_settings_url,
            },
          }
        end

        def authorize_secrets!
          authorize!(current_visitor, to: :show?)
        end
      end
    end
  end
end
