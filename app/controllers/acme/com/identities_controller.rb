# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class IdentitiesController < Acme::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def show
        authorize!(current_visitor, to: :show?)
        render "acme/shared/identities/show", locals: { surface: :com, page_title: "Identity" }
      end
    end
  end
end
