# typed: false
# frozen_string_literal: true

module Sign
  module App
    class GuestController < ApplicationController
      AUTHENTICATION_MODE = :guest

      declare_authentication_mode! :guest, status: :unauthorized

      private

      def handle_guest_only_with_status_checks(options)
        return super if options[:no_redirect]
        return handle_guest_only_html(options) if request.get? && !request.format.json?

        super
      end

      # Redirect logged-in users from guest-only pages to the signed-in landing page.
      def after_login_path
        sign_app_dashboard_path
      end
    end
  end
end
