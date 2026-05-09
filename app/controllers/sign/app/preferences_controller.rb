# typed: false
# frozen_string_literal: true

module Sign
  module App
    class PreferencesController < ApplicationController
      skip_before_action :set_preferences_cookie, only: :show, raise: false
      before_action :set_email_path

      def show
      end

      private

      def set_email_path
        @preference_email_path = new_sign_app_preference_email_path
      end
    end
  end
end
