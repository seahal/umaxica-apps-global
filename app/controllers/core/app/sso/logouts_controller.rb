# typed: false
# frozen_string_literal: true

module Core
  module App
    module Sso
      class LogoutsController < Core::App::ApplicationController
        include ::OidcRpLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
