# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      class EmailsController < Sign::Org::BareController
        AUTHENTICATION_MODE = :bare

        include Sign::PromotionalEmailUnsubscribeActions

        private

        def promotional_email_model
          OperatorEmail
        end

        def promotional_email_scope
          :operator
        end

        def redirect_after_unsubscribe_path(token:)
          edit_sign_org_preference_email_path(@email, token: token)
        end
      end
    end
  end
end
