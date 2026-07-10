# typed: false
# frozen_string_literal: true

module Auth
  module Com
    class FullAccessController < ::Auth::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private
    end
  end
end
