# typed: false
# frozen_string_literal: true

module Base
  module Com
    class SettingsController < Base::Com::BareController
      AUTHENTICATION_MODE = :bare

      def show
        render plain: "Settings"
      end
    end
  end
end
