# typed: false
# frozen_string_literal: true

module Base
  module App
    module Preference
      # Promotional email unsubscribe boundary for the app surface.
      # Bare endpoint: token-authenticated, not part of the preference-write pipeline.
      class EmailsController < ::Base::App::BareController
        include PromotionalEmailUnsubscribeActions

        AUTHENTICATION_MODE = :bare
        before_action :set_promotional_email

        private

        def promotional_email_model
          ClientEmail
        end

        def promotional_email_scope
          :client
        end

        def redirect_after_unsubscribe_path(token:)
          edit_base_app_preference_email_path(@email, token: token)
        end
      end
    end
  end
end
