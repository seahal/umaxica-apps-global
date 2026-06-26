# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Identity
      class BaseController < Acme::App::FullAccessController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
      end
    end
  end
end
