# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Sso
      class LogoutsController < Base::Org::ApplicationController
        include ::OidcRpLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
