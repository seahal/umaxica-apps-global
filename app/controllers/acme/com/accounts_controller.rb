# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class AccountsController < Acme::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def index = show

      def show
        authorize!(current_visitor, to: :show?)
        render "acme/shared/self_service/show", locals: { page_title: "Account" }
      end
    end
  end
end
