# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class OutsController < PrivateController
      include ::Verification::Operator
      include ::Authentication::Logoutable
      include ::Sign::OutNotice

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
        logout_current_session!(reason: "org_operator_logout")
        issue_sign_out_notice!
        redirect_to(sign_org_signed_out_path(ri: params[:ri]), status: :see_other)
      end

      private
    end
  end
end
