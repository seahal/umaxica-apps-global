# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class BaseController < Base::App::FullAccessController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
      end
    end
  end
end
