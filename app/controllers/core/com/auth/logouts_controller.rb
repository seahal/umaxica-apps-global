# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Auth
      class LogoutsController < Core::Com::ApplicationController
        include ::OidcRpLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
