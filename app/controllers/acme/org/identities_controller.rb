# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class IdentitiesController < Acme::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        authorize!(current_operator, to: :show?)
        render "acme/shared/identities/show", locals: { surface: :org, page_title: "Identity" }
      end
    end
  end
end
