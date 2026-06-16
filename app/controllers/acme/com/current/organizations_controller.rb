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
        end

        def edit
          authorize!(current_visitor, to: :update?)
        end

        def update
          authorize!(current_visitor, to: :update?)
          redirect_to(acme_com_current_organization_path(ri: params[:ri]), status: :see_other)
        end
      end
    end
  end
end
