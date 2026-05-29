# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Sso
      class LogoutsController < Core::Org::ApplicationController
        include ::Oidc::RpLogout

        AUTHENTICATION_MODE = :open
      end
    end
  end
end
