# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Preference
      class EmailsController < Sign::Com::BareController
        include Sign::PromotionalEmailUnsubscribeActions

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
          edit_sign_com_preference_email_path(@email, token: token)
        end
      end
    end
  end
end
