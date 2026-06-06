# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Oauth
      class JwksController < ::Sign::App::JwksController
        AUTHENTICATION_MODE = :bare
      end
    end
  end
end
