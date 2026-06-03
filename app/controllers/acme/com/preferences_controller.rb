# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class PreferencesController < PreferencesBaseController
      AUTHENTICATION_MODE = :open

      skip_before_action :set_preferences_cookie, only: :show, raise: false

      def show
        render "sign/com/preferences/show"
      end
    end
  end
end
