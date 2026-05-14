# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class OutsController < ApplicationController
        include ::Verification::User

        auth_required!
        before_action :authenticate!

        def edit
        end

        def create
          unless ActiveModel::Type::Boolean.new.cast(params[:confirm])
            redirect_to(
              edit_sign_app_out_path(ri: params[:ri]),
              alert: t("views.sign.app.configuration.outs.edit.confirm_label"),
            )
            return
          end

          destroy
        end

        def destroy
          Oidc::SingleLogoutService.call(user: current_user) if current_user
          log_out
          redirect_to(sign_app_root_path, notice: t("sign.shared.sign_out.success"))
        end

        private
      end
    end
  end
end
