# typed: false
# frozen_string_literal: true

module Acme
  module App
    class PreferencesController < PreferencesBaseController
      AUTHENTICATION_MODE = :open

      skip_before_action :set_preferences_cookie, only: :show, raise: false

      def show
        render "acme/shared/preferences/show"
      end
    end
  end
end
