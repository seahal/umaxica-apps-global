# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class RecoveriesController < ::Base::Com::ApplicationController
        include CommonRedirect
        include EnforcementRecoveryCeremonyCookie

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        before_action :require_recovery_ceremony!

        def show
          @enforcement_cases = ComEnforcementCase.in_force.where(
            principal_public_id: current_recovery_ceremony.subject.public_id, kind: "security_lock", visibility: "visible",
            release_mode: "verification_required",
          )
          render "base/com/identity/recoveries/show"
        end

        private

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
