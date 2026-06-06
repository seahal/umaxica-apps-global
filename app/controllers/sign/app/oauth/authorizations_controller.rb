# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Oauth
      class AuthorizationsController < ::Sign::App::AuthorizesController
        AUTHENTICATION_MODE = :private
      end
    end
  end
end
