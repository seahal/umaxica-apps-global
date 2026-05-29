# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class RootsController < Sign::Org::ApplicationController
      AUTHENTICATION_MODE = :guest

      skip_before_action :set_preferences_cookie, only: :index, raise: false

      def index
      end
    end
  end
end
