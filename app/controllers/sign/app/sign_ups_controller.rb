# typed: false
# frozen_string_literal: true

module Sign
  module App
    class SignUpsController < ::Sign::App::ApplicationController
      AUTHENTICATION_MODE = :guest

      def new
      end
    end
  end
end
