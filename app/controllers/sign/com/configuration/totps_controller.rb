# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class TotpsController < ApplicationController
        auth_required!

        before_action :authenticate_customer!

        def index
          redirect_unavailable!
        end

        def new
          redirect_unavailable!
        end

        def edit
          redirect_unavailable!
        end

        def create
          redirect_unavailable!
        end

        def update
          redirect_unavailable!
        end

        def destroy
          redirect_unavailable!
        end

        private

        def redirect_unavailable!
          redirect_to(
            sign_com_configuration_path(ri: params[:ri]),
            alert: t("auth.step_up.method_unavailable"),
            status: :see_other,
          )
        end
      end
    end
  end
end
