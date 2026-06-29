# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class RotationsController < Secrets::RotationsController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
      end
    end
  end
end
