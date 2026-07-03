# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      module Privacy
        class ErasuresController < ::Base::Com::ApplicationController
          include CommonRedirect
          include WithdrawalCeremonyAuthentication
          include PrivacyErasureRequestFlow

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          before_action :withdrawal_ceremony_required!

          def new
            render_privacy_erasure_new(current_withdrawal_subject)
          end

          def create
            create_privacy_erasure_request!(current_withdrawal_subject)
          end

          def status
            render_privacy_erasure_status(current_withdrawal_subject)
          end

          private

          def withdrawal_ceremony_class = VisitorWithdrawalCeremony

          def privacy_request_class = VisitorPrivacyRequest

          def privacy_subject_key = :visitor

          def processor_notification_class = VisitorProcessorErasureNotification

          def processor_privacy_request_key = :visitor_privacy_request

          def privacy_erasure_surface = :com

          def withdrawal_new_path(extra_params = {})
            new_base_com_identity_withdrawal_session_path({ ri: params[:ri] }.merge(extra_params))
          end

          def privacy_erasure_new_path = new_base_com_identity_privacy_erasure_path(ri: params[:ri])

          def privacy_erasure_status_path = status_base_com_identity_privacy_erasure_path(ri: params[:ri])

          def withdrawal_public_fallback_path = auth_com_sign_in_path
        end
      end
    end
  end
end
