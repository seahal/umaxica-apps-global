# typed: false
# frozen_string_literal: true

module Sign
  module App
    class GuestController < ApplicationController
      AUTHENTICATION_MODE = :guest

      declare_authentication_mode! :guest, status: :unauthorized

      before_action :reject_logged_in_session

      private

      def handle_guest_only_with_status_checks(options)
        return super if options[:no_redirect]
        return handle_guest_only_html(options) if request.get? && !request.format.json?

        super
      end

      def reject_logged_in_session
        return unless logged_in?

        if request.get? && !request.format.json?
          handle_guest_only_html({})
        else
          render plain: I18n.t("errors.messages.already_authenticated"), status: :unauthorized
        end
      end
    end
  end
end
