# typed: false
# frozen_string_literal: true

module Base
  module App
    class SettingsController < Base::App::BareController
      AUTHENTICATION_MODE = :bare

      def show
        render plain: "Settings"
      end
    end
  end
end
