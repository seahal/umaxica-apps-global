# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Privacy
        module Erasure
          # Shows the state of the latest self-service erasure request made
          # during the withdrawal ceremony.
          class StatusesController < ::Base::App::Identity::BaseController
            include CommonRedirect
            include WithdrawalCeremonyAuthentication
            include PrivacyErasureRequestFlow

            AUTHENTICATION_MODE = :open
            declare_authentication_mode! :open

            before_action :withdrawal_ceremony_required!

            def show
              render_privacy_erasure_status(current_withdrawal_subject)
            end

            private

            def withdrawal_ceremony_class = ClientWithdrawalCeremony

            def withdrawal_new_path(extra_params = {})
              new_base_app_identity_withdrawal_session_path({ ri: params[:ri] }.merge(extra_params))
            end

            def withdrawal_public_fallback_path = auth_app_sign_in_path
          end
        end
      end
    end
  end
end
