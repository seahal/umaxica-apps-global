# typed: false
# frozen_string_literal: true

module Sign
  module Social
    module OrgGoogleSigninGate
      SIGNIN_ENABLED_ENV = "ORG_GOOGLE_SIGNIN_ENABLED"

      module_function

      def enabled?(env: ENV)
        env[SIGNIN_ENABLED_ENV].to_s.casecmp("true").zero?
      end
    end
  end
end
