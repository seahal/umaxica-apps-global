# typed: false
# frozen_string_literal: true

module Sign
  module App
    class PreferencesController < ApplicationController
      public_strict!
      skip_before_action :set_preferences_cookie, only: :show, raise: false

      def show
      end
    end
  end
end
