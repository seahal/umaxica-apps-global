# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Preference
      # Promotional email unsubscribe boundary for the org surface.
      # Bare endpoint: token-authenticated, not part of the preference-write pipeline.
      class EmailsController < ::Acme::Org::BareController
        include PromotionalEmailUnsubscribeActions

        AUTHENTICATION_MODE = :bare
        before_action :set_promotional_email

        private

        def promotional_email_model
          OperatorEmail
        end

        def promotional_email_scope
          :operator
        end

        def redirect_after_unsubscribe_path(token:)
          edit_acme_org_preference_email_path(@email, token: token)
        end
      end
    end
  end
end
