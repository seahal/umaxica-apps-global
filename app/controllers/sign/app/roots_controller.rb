# typed: false
# frozen_string_literal: true

module Sign
  module App
    class RootsController < Sign::App::ApplicationController
      AUTHENTICATION_MODE = :guest

      skip_before_action :set_preferences_cookie, only: :index, raise: false

      def index
      end
    end
  end
end
