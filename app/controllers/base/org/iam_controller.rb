# typed: false
# frozen_string_literal: true

module Base
  module Org
    class IamController < Base::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def index
        authorize!(:org_staff, to: :index?, with: OrgStaffPolicy)
        render json: { status: "ok" }
      end
    end
  end
end
