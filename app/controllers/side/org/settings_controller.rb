# typed: false
# frozen_string_literal: true

module Side
  module Org
    class SettingsController < Side::Org::BareController
      AUTHENTICATION_MODE = :bare

      def show
        render plain: "Settings"
      end
    end
  end
end
