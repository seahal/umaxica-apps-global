# typed: false
# frozen_string_literal: true

module Apex
  module App
    module Sso
      class LogoutsController < OpenController
        include ::Oidc::RpLogout

        AUTHENTICATION_MODE = :open
      end
    end
  end
end
