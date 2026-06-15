# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Support
      class AccountSessionsController < Acme::Org::ApplicationController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
      end
    end
  end
end
