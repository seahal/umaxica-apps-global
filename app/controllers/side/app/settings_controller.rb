# typed: false
# frozen_string_literal: true

module Side
  module App
    class SettingsController < Side::App::ApplicationController
      include ::SideSettingsPage

      # Reachable from the anonymous Side landing, which links here before the visitor signs in.
      AUTHENTICATION_MODE = :open

      def show
        render inertia: true, props: settings_page_props
      end
    end
  end
end
