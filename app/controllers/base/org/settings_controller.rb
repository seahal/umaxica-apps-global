# typed: false
# frozen_string_literal: true

module Base
  module Org
    class SettingsController < Base::Org::BareController
      AUTHENTICATION_MODE = :bare

      def show
        render plain: "Settings"
      end
    end
  end
end
