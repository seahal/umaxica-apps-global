# typed: false
# frozen_string_literal: true

module Apex
  module Com
    class GuestController < ApplicationController
      AUTHENTICATION_MODE = :guest

      declare_authentication_mode! :guest, status: :unauthorized

      private

      def after_login_path
        apex_com_root_path
      end
    end
  end
end
