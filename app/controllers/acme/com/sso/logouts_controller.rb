# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Sso
      class LogoutsController < Acme::Com::ApplicationController
        include ::OidcRpLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
