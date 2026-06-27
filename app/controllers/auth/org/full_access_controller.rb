# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class FullAccessController < ::Auth::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private
    end
  end
end
