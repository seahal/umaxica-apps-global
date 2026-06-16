# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Current
      class OrganizationsController < Acme::Com::ApplicationController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!

        def show
          authorize!(current_visitor, to: :show?)
          render "acme/shared/self_service/show", locals: { page_title: "Current Organization" }
        end

        def edit
          authorize!(current_visitor, to: :update?)
          render "acme/shared/self_service/show", locals: { page_title: "Current Organization" }
        end

        def update
          authorize!(current_visitor, to: :update?)
          render "acme/shared/self_service/show", locals: { page_title: "Current Organization" }
        end
      end
    end
  end
end
