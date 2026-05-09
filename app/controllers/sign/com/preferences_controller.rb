# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class PreferencesController < Sign::Com::ApplicationController
      public_strict!
      skip_before_action :set_preferences_cookie, only: :show, raise: false
      before_action :set_email_path

      def show
      end

      private

      def set_email_path
        @preference_email_path = new_sign_com_preference_email_path(ri: params[:ri])
      end
    end
  end
end
