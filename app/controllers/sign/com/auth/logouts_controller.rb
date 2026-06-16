# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Auth
      class LogoutsController < ::Sign::Com::ApplicationController
        include ::OidcRpLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
