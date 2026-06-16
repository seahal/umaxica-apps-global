# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Auth
      class LogoutsController < Acme::Org::ApplicationController
        include ::OidcRpLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
