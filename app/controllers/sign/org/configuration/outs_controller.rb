# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class OutsController < ApplicationController
        include ::Verification::Operator

        auth_required!
        before_action :authenticate!

        def edit
        end

        def create
          unless ActiveModel::Type::Boolean.new.cast(params[:confirm])
            redirect_to(
              edit_sign_org_out_path(ri: params[:ri]),
              alert: t("views.sign.app.configuration.outs.edit.confirm_label"),
            )
            return
          end

          destroy
        end

        def destroy
          Oidc::SingleLogoutService.call_for_staff(staff: current_operator) if current_operator
          log_out
          redirect_to(sign_org_root_path, notice: t("sign.shared.sign_out.success"))
        end

        private
      end
    end
  end
end
