# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Auth
      class LogoutsController < Core::Org::ApplicationController
        include ::OidcRpLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
