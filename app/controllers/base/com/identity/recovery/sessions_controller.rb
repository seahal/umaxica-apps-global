# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      module Recovery
        class SessionsController < ::Base::Com::ApplicationController
          include CommonRedirect
          include EnforcementRecoveryCeremonyCookie
          include EnforcementRecoveryCeremonyFlow

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          rate_limit to: 5, within: 1.minute, by: -> { request.remote_ip }, scope: "base_com_enforcement_recovery",
                     name: "email_create_ip_burst", store: rate_limit_store, only: :create,
                     with: -> { render_rate_limited(rule_name: "base_com_enforcement_recovery_email_create_ip_burst", retry_after: 60) }

          private

          def identity_email_model = VisitorEmail
          def recovery_subject_from_email(email) = email&.visitor
          def recovery_surface = :com
          def recovery_ceremony_class = VisitorEnforcementRecoveryCeremony
          def recovery_case_class = ComEnforcementCase
          def recovery_email_status_column = :visitor_email_status_id
          def recovery_verified_email_status_ids = VisitorEmail::EDITABLE_SUBSCRIPTION_PREFERENCE_STATUS_IDS
          def recovery_entry_path = new_base_com_identity_recovery_session_path
          def recovery_status_path = base_com_identity_recovery_path
        end
      end
    end
  end
end
