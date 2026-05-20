# typed: false
# frozen_string_literal: true

module Apex
  module Org
    class GuestController < ApplicationController
      guest_only! status: :unauthorized

      private

      def after_login_path
        apex_org_root_path
      rescue StandardError
        "/"
      end
    end
  end
end
