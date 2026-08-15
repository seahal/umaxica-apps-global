# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Preference
      # Promotional email unsubscribe boundary for the com surface.
      # Bare endpoint: token-authenticated, not part of the preference-write pipeline.
      class EmailsController < ::Base::Com::BareController
        include PromotionalEmailUnsubscribeActions
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :bare
        before_action :set_promotional_email

        # The unsubscribe screen is reached from an email with a signed token rather than a session,
        # so everything it shows is derived from that token's email here.
        def edit
          render inertia: true, props: unsubscribe_page_props
        end

        private

        def unsubscribe_page_props
          promotional = @email.promotional?

          {
            title: "Email settings",
            heading: "Email Preferences",
            promotional: promotional,
            description:
              if promotional
                t("base.com.preference.emails.unsubscribe.description")
              else
                t("base.com.preference.emails.unsubscribe.disabled_description")
              end,
            form: promotional ? unsubscribe_form_props : nil,
          }
        end

        def unsubscribe_form_props
          site_key = Rails.app.creds.option(:CLOUDFLARE_TURNSTILE_VISIBLE_SITE_KEY)
          raise KeyError, "CLOUDFLARE_TURNSTILE_VISIBLE_SITE_KEY is required" if site_key.blank?

          {
            action: base_com_preference_email_path(@email),
            token: params[:token].to_s,
            submit_label: "Unsubscribe",
            turnstile_site_key: site_key,
          }
        end

        def promotional_email_model
          VisitorEmail
        end

        def promotional_email_scope
          :visitor
        end

        def redirect_after_unsubscribe_path(token:)
          edit_base_com_preference_email_path(@email, token: token)
        end
      end
    end
  end
end
