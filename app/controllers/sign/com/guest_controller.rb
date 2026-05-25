# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class GuestController < ApplicationController
      AUTHENTICATION_MODE = :guest

      declare_authentication_mode! :guest, status: :unauthorized

      before_action :reject_logged_in_session

      private

      def after_login_path
        sign_com_dashboard_path
      end
    end
  end
end
