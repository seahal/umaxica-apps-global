# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class OutsController < OpenController
      include ::Verification::Operator
      include ::Authentication::Logoutable
      include ::Sign::OutNotice

      before_action :authenticate!, only: %i(edit create destroy)

      def show
        @sign_out_notice = consume_sign_out_notice
        return if @sign_out_notice.present?

        redirect_to(edit_sign_org_out_path(ri: params[:ri]))
      end

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
        rt = params[:rt].presence
        destination = safe_path_from_encoded_rt(rt, fallback: nil) if rt.present?

        logout_current_session!(reason: "org_operator_logout")
        return render_invalid_return_target! if rt.present? && destination.blank?
        return redirect_to_return_target_destination!(destination) if destination.present?

        render :show
      end

      private
    end
  end
end
