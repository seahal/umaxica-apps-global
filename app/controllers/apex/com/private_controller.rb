# typed: false
# frozen_string_literal: true

module Apex
  module Com
    class PrivateController < ApplicationController
      AUTHENTICATION_MODE = :private

      declare_authentication_mode! :private
    end
  end
end
