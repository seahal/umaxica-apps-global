# typed: false
# frozen_string_literal: true

module Side
  module Com
    class SettingsController < Side::Com::BareController
      AUTHENTICATION_MODE = :bare

      def show
        render plain: "Settings"
      end
    end
  end
end
