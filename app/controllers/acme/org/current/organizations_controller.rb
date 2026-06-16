# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Current
      class OrganizationsController < Acme::Org::ApplicationController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_operator!

        def show
          authorize!(current_operator, to: :show?)
          render "acme/shared/self_service/show", locals: { page_title: "Current Organization" }
        end

        def edit
          authorize!(current_operator, to: :update?)
          render "acme/shared/self_service/show", locals: { page_title: "Current Organization" }
        end

        def update
          authorize!(current_operator, to: :update?)
          render "acme/shared/self_service/show", locals: { page_title: "Current Organization" }
        end
      end
    end
  end
end
