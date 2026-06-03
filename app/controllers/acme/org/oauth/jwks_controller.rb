# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Oauth
      class JwksController < Acme::Org::JwksController
        AUTHENTICATION_MODE = :bare
      end
    end
  end
end
