# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class FullAccessController < ::Sign::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private
    end
  end
end
