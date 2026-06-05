# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class AccountsController < Acme::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def index = show

      def show
        authorize!(current_operator, to: :show?)
        render "acme/shared/self_service/show", locals: { page_title: "Account" }
      end
    end
  end
end
