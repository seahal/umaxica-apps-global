# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class SignUpsController < ::Sign::Com::ApplicationController
      AUTHENTICATION_MODE = :guest
    end
  end
end
