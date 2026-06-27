# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Session
      class LogoutsController < ::Auth::Org::ApplicationController
        include ::OidcRpLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
