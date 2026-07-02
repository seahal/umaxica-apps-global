# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Organizations
      class MembershipsController < Base::Org::ApplicationController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_operator!

        def index
          render json: []
        end

        def show
          render json: {}
        end

        def new
          render plain: "New Membership"
        end

        def edit
          render plain: "Edit Membership"
        end

        def create
          head :unprocessable_content
        end

        def update
          head :unprocessable_content
        end

        def destroy
          head :no_content
        end
      end
    end
  end
end
