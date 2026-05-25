# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Oidc
      class LogoutsController < Sign::App::LogoutsController
        AUTHENTICATION_MODE = :open

      end
    end
  end
end
