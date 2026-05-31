# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Sso
      class LogoutsController < Acme::Org::ApplicationController
        include ::Oidc::RpLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
