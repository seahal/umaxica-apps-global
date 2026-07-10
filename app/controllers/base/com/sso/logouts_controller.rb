# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Sso
      class LogoutsController < Base::Com::ApplicationController
        include ::OidcRpLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
