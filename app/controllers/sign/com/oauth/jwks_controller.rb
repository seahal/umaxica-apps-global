# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Oauth
      class JwksController < Sign::Com::JwksController
        AUTHENTICATION_MODE = :bare
      end
    end
  end
end
