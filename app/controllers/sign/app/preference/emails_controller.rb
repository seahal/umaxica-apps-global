# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Preference
      class EmailsController < Sign::App::BareController
        include Sign::PromotionalEmailUnsubscribeActions

        private

        def promotional_email_model
          ClientEmail
        end

        def promotional_email_scope
          :client
        end

        def redirect_after_unsubscribe_path(token:)
          edit_sign_app_preference_email_path(@email, token: token)
        end
      end
    end
  end
end
