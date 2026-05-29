# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Sso
      class LogoutsController < Acme::App::ApplicationController
        include ::Oidc::RpLogout

        AUTHENTICATION_MODE = :open
      end
    end
  end
end
