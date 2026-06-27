# typed: false
# frozen_string_literal: true

module Base
  module Org
    class OrganizationsController < Base::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def index
        authorize!(current_operator, to: :show?)
        @organizations = Bureau.all
      end

      def show
        @organization = find_organization!
        authorize!(current_operator, to: :show?)
      end

      private

      def find_organization!
        Bureau.find_by!(public_id: params.expect(:id))
      end
    end
  end
end
