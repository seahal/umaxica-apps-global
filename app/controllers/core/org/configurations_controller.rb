# typed: false
# frozen_string_literal: true

module Core
  module Org
    class ConfigurationsController < Core::Org::ApplicationController
      AUTHENTICATION_MODE = :private

      def show
        authorize!(:org_staff, to: :show?, with: OrgStaffPolicy)
        render template: "acme/org/roots/index"
      end
    end
  end
end
