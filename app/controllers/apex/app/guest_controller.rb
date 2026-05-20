# typed: false
# frozen_string_literal: true

module Apex
  module App
    class GuestController < ApplicationController
      guest_only! status: :unauthorized

      private

      def after_login_path
        apex_app_root_path
      rescue StandardError
        "/"
      end
    end
  end
end
