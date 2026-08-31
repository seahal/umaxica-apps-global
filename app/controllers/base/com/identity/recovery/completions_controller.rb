# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      module Recovery
        class CompletionsController < ::Base::Com::ApplicationController
          include CommonRedirect
          include EnforcementRecoveryCeremonyCookie

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open
          before_action :require_recovery_ceremony!

          def create
            EnforcementCaseEndOperation.call(enforcement_case: recovery_case, reason: "verification_completed")
            current_recovery_ceremony.consume!
            clear_recovery_ceremony_cookie!
            safe_redirect_to(auth_com_sign_in_path, fallback: new_base_com_identity_recovery_session_path, status: :see_other)
          end

          private

          def recovery_case
            ComEnforcementCase.in_force.find_by!(
              public_id: params.expect(:enforcement_case_id), principal_public_id: current_recovery_ceremony.subject.public_id,
              kind: "security_lock", visibility: "visible", release_mode: "verification_required",
            )
          end

          def recovery_ceremony_class = VisitorEnforcementRecoveryCeremony

          def require_recovery_ceremony!
            return if current_recovery_ceremony

            clear_recovery_ceremony_cookie!
            safe_redirect_to(new_base_com_identity_recovery_session_path, fallback: auth_com_sign_in_path, status: :see_other)
          end
        end
      end
    end
  end
end
