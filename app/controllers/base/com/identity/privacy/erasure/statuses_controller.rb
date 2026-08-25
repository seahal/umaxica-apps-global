# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      module Privacy
        module Erasure
          # Shows the state of the latest self-service erasure request made
          # during the withdrawal ceremony.
          class StatusesController < ::Base::Com::ApplicationController
            include ::SurfaceInertiaPage
            include CommonRedirect
            include WithdrawalCeremonyAuthentication
            include PrivacyErasureRequestFlow

            AUTHENTICATION_MODE = :open
            declare_authentication_mode! :open

            before_action :withdrawal_ceremony_required!

            def show
              render_privacy_erasure_status(current_withdrawal_subject)
              render inertia: true, props: show_page_props
            end

            private

            def show_page_props
              {
                title: "Privacy erasure status",
                empty_message: t("base.com.identity.privacy.erasure.statuses.show.empty_message"),
                privacy_request: serialize_privacy_request(@privacy_request),
              }
            end

            def serialize_privacy_request(privacy_request)
              return if privacy_request.blank?

              {
                status_label: VisitorPrivacyRequest.status_name_for(privacy_request.status_id).downcase,
                status_term: "Status",
                received_term: "Received",
                received_at: privacy_request.received_at&.iso8601,
                response_due_term: "Response due",
                response_due_at: privacy_request.response_due_at&.iso8601,
              }
            end

            def withdrawal_ceremony_class = VisitorWithdrawalCeremony

            def withdrawal_new_path(extra_params = {})
              new_base_com_identity_withdrawal_session_path({ ri: params[:ri] }.merge(extra_params))
            end

            def withdrawal_public_fallback_path = auth_com_sign_in_path
          end
        end
      end
    end
  end
end
