# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Oauth
      class JwksController < Acme::App::JwksController
        AUTHENTICATION_MODE = :bare
      end
    end
  end
end
