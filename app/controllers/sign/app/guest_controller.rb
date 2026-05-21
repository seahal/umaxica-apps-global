# typed: false
# frozen_string_literal: true

module Sign
  module App
    class GuestController < ApplicationController
      guest_only! status: :unauthorized

      private

      def handle_guest_only_with_status_checks(options)
        return handle_guest_only_html(options) if request.get? && !request.format.json?

        super
      end

      # Redirect logged-in users from guest-only pages to the signed-in landing page.
      def after_login_path
        sign_app_dashboard_path
      rescue StandardError
        "/"
      end
    end
  end
end
