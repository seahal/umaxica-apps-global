# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class SignOutsController < Acme::Com::ApplicationController
      include ::Authentication::Logoutable
      include ::Sign::OutNotice

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      before_action :authenticate!, only: %i(edit create destroy)
      helper_method :sign_out_completed_description

      def show
        @sign_out_notice = consume_sign_out_notice
        return render "acme/shared/sign_outs/show" if @sign_out_notice.present?

        redirect_to(edit_acme_com_sign_out_path(ri: params[:ri]))
      end

      def edit
        render "acme/shared/sign_outs/edit"
      end

      def create
        unless ActiveModel::Type::Boolean.new.cast(params[:confirm])
          redirect_to(
            edit_acme_com_sign_out_path(ri: params[:ri]),
            alert: t("views.sign.app.settings.outs.edit.confirm_label"),
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
        logout_current_session!(reason: "com_visitor_logout")
        return render_invalid_return_target! if raw_pt.present? && destination.blank?
        return redirect_to_pt_destination!(destination) if destination.present?

        render "acme/shared/sign_outs/show"
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
