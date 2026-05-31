# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Sso
      class LogoutsController < Core::Com::ApplicationController
        include ::Oidc::RpLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
