# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Preference
      # Promotional email unsubscribe boundary for the com surface.
      # Bare endpoint: token-authenticated, not part of the preference-write pipeline.
      class EmailsController < ::Base::Com::BareController
        include PromotionalEmailUnsubscribeActions

        AUTHENTICATION_MODE = :bare
        before_action :set_promotional_email

        private

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
