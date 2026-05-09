# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class RootsController < ApplicationController
      guest_only! status: :unauthorized
      skip_before_action :set_preferences_cookie, only: :index, raise: false

      def index
      end
    end
  end
end
