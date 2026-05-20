# typed: false
# frozen_string_literal: true

module Sign
  module App
    class OutsController < PrivateController
      include ::Verification::Client
      include ::Authentication::Logoutable
      include ::Sign::OutNotice

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
        logout_current_session!(reason: "app_user_logout")
        issue_sign_out_notice!
        redirect_to(sign_app_signed_out_path(ri: params[:ri]), status: :see_other)
      end

      private
    end
  end
end
