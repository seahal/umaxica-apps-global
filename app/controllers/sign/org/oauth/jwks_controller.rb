# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Oauth
      class JwksController < Sign::Org::JwksController
        AUTHENTICATION_MODE = :bare
      end
    end
  end
end
