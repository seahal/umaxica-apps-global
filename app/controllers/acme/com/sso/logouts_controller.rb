# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Sso
      class LogoutsController < Acme::Com::ApplicationController
        include ::Oidc::RpLogout

        AUTHENTICATION_MODE = :open
      end
    end
  end
end
