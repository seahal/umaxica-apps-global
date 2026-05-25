# typed: false
# frozen_string_literal: true

module Sign
  module App
    class PrivateController < ApplicationController
      AUTHENTICATION_MODE = :private

      declare_authentication_mode! :private
    end
  end
end
