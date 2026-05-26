# typed: false
# frozen_string_literal: true

module Sign
  module App
    class OutsController < OpenController
      include ::Verification::Client

      include ::Authentication::Logoutable

      include ::Sign::OutNotice

      AUTHENTICATION_MODE = :open

      before_action :authenticate!, only: %i(edit create destroy)

      def show
        @sign_out_notice = consume_sign_out_notice
        return if @sign_out_notice.present?

        redirect_to(edit_sign_app_out_path(ri: params[:ri]))
      end

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
        pt = params[:pt].presence
        destination = path_from_signed_pt(pt) if pt.present?

        logout_current_session!(reason: "app_user_logout")
        return render_invalid_return_target! if pt.present? && destination.blank?
        return redirect_to_pt_destination!(destination) if destination.present?

        render :show
      end

      private
    end
  end
end
