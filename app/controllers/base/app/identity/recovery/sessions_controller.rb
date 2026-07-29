# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Recovery
        class SessionsController < ::Base::App::Identity::BaseController
          include CommonRedirect
          include EnforcementRecoveryCeremonyCookie
          include EnforcementRecoveryCeremonyFlow

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          rate_limit to: 5, within: 1.minute, by: -> { request.remote_ip }, scope: "base_app_enforcement_recovery",
                     name: "email_create_ip_burst", store: rate_limit_store, only: :create,
                     with: -> { render_rate_limited(rule_name: "base_app_enforcement_recovery_email_create_ip_burst", retry_after: 60) }

          private

          def identity_email_model = ClientEmail
          def recovery_subject_from_email(email) = email&.user
          def recovery_surface = :app
          def recovery_ceremony_class = ClientEnforcementRecoveryCeremony
          def recovery_case_class = AppEnforcementCase
          def recovery_email_status_column = :user_email_status_id
          def recovery_verified_email_status_ids = ClientEmail::EDITABLE_SUBSCRIPTION_PREFERENCE_STATUS_IDS
          def recovery_entry_path = new_base_app_identity_recovery_session_path
          def recovery_status_path = base_app_identity_recovery_path
        end
      end
    end
  end
end
