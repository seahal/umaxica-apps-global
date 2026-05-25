# typed: false
# frozen_string_literal: true

module Apex
  module Com
    module Sso
      class LogoutsController < OpenController
        AUTHENTICATION_MODE = :open

        include ::Oidc::RpLogout
      end
    end
  end
end
