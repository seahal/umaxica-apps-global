# typed: false
# frozen_string_literal: true

module Sign
  module App
    class SignOutsController < Sign::App::ApplicationController
      include ::Verification::Client

      include ::Authentication::Logoutable

      include ::Sign::OutNotice

      AUTHENTICATION_MODE = :open

      prepend_before_action :authenticate!, only: %i(edit create destroy)
      helper_method :sign_out_completed_description

      def show
        @sign_out_notice = consume_sign_out_notice
        return if @sign_out_notice.present?

        redirect_to(edit_sign_app_sign_out_path(ri: params[:ri]))
      end

      def edit
      end

      def create
        unless ActiveModel::Type::Boolean.new.cast(params[:confirm])
          redirect_to(
            edit_sign_app_sign_out_path(ri: params[:ri]),
            alert: t("views.sign.app.configuration.outs.edit.confirm_label"),
          )
          return
        end

        perform_sign_out!
      end

      def destroy
        perform_sign_out!
      end

      private

      def perform_sign_out!
        raw_pt = path_target_value
        pt = signed_pt_param
        destination = path_from_signed_pt(pt) if pt.present?

        return if authorize_current_session_for_sign_out! == false

        prepare_sign_out_completion_notice!
        logout_current_session!(reason: "app_user_logout")
        return render_invalid_return_target! if raw_pt.present? && destination.blank?
        return redirect_to_pt_destination!(destination) if destination.present?

        render :show
      end

      def authorize_current_session_for_sign_out!
        return true if current_session.blank?
        return true if allowed_to?(:destroy?, current_session, context: { user: current_resource })

        head :forbidden
        false
      end
    end
  end
end
