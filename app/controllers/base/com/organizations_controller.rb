# typed: false
# frozen_string_literal: true

module Base
  module Com
    class OrganizationsController < Base::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def index
        authorize!(current_visitor, to: :show?)
        @organizations = Company.all
      end

      def show
        @organization = find_organization!
        authorize!(current_visitor, to: :show?)
      end

      private

      def find_organization!
        Company.find_by!(public_id: params.expect(:id))
      end
    end
  end
end
