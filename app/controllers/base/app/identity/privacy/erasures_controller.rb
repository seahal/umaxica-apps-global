# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Privacy
        class ErasuresController < BaseController
          include ::SurfaceInertiaPage
          include CommonRedirect
          include WithdrawalCeremonyAuthentication
          include PrivacyErasureRequestFlow

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          before_action :withdrawal_ceremony_required!

          def new
            render_privacy_erasure_new(current_withdrawal_subject)
            return if performed?

            render inertia: true, props: {
              title: "Early personal data erasure",
              notices: [
                "This is a privacy request for personal data deletion or restriction. It is separate " \
                "from normal withdrawal.",
                "After processing, recovery may no longer be available. Some data may be retained for " \
                "legal, safety, audit, billing, or dispute handling reasons.",
                "Messages, posts, audit logs, billing records, and similar records may follow separate " \
                "retention policies.",
              ],
              form: {
                action: base_app_identity_privacy_erasure_path(ri: params[:ri]),
                jurisdiction: "unknown",
                submit_label: "Request early erasure",
              },
            }
          end

          def create
            create_privacy_erasure_request!(current_withdrawal_subject)
          end

          private

          def withdrawal_ceremony_class = ClientWithdrawalCeremony

          def privacy_request_class = ClientPrivacyRequest

          def privacy_subject_key = :client

          def processor_notification_class = ClientProcessorErasureNotification

          def processor_privacy_request_key = :client_privacy_request

          def privacy_erasure_surface = :app

          def withdrawal_new_path(extra_params = {})
            new_base_app_identity_withdrawal_session_path({ ri: params[:ri] }.merge(extra_params))
          end

          def privacy_erasure_new_path = new_base_app_identity_privacy_erasure_path(ri: params[:ri])

          def privacy_erasure_status_path = base_app_identity_privacy_erasure_status_path(ri: params[:ri])

          def withdrawal_public_fallback_path = auth_app_sign_in_path
        end
      end
    end
  end
end
