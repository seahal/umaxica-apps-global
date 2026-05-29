# typed: false
# frozen_string_literal: true

module Acme
  module App
    class GuestController < ApplicationController
      AUTHENTICATION_MODE = :guest

      declare_authentication_mode! :guest, status: :unauthorized

      private

      def after_login_path
        acme_app_root_path
      end
    end
  end
end
