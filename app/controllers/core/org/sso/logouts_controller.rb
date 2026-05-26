# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Sso
      class LogoutsController < OpenController
        include ::Oidc::RpLogout

        AUTHENTICATION_MODE = :open
      end
    end
  end
end
