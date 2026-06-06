# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Sso
      class LogoutsController < Acme::App::ApplicationController
        include ::OidcRpLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
