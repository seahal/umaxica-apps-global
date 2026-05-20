# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class GuestController < ApplicationController
      guest_only! status: :unauthorized

      before_action :reject_logged_in_session

      private

      def after_login_path
        sign_com_dashboard_path
      rescue StandardError
        "/"
      end
    end
  end
end
