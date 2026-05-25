# typed: false
# frozen_string_literal: true

module Apex
  module Org
    class GuestController < ApplicationController
      AUTHENTICATION_MODE = :guest

      declare_authentication_mode! :guest, status: :unauthorized

      private

      def after_login_path
        apex_org_root_path
      end
    end
  end
end
