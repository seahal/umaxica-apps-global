# typed: false
# frozen_string_literal: true

module Side
  module App
    class SettingsController < Side::App::BareController
      AUTHENTICATION_MODE = :bare

      def show
        render plain: "Settings"
      end
    end
  end
end
