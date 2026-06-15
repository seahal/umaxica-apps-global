# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Oauth
      class JwksController < Acme::Org::WellKnown::JwksController
        AUTHENTICATION_MODE = :bare
      end
    end
  end
end
