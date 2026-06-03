# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Oauth
      class JwksController < Acme::Com::JwksController
        AUTHENTICATION_MODE = :bare
      end
    end
  end
end
