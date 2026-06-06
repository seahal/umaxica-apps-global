# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Sign
      module Out
        class AttemptsController < ::Sign::Com::ApplicationController
          include ::AuthenticationLogoutable
          include ::SignOutNotice

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          before_action :authenticate_visitor!

          def create
            unless ActiveModel::Type::Boolean.new.cast(params[:confirm])
              redirect_to(
                sign_com_sign_out_confirmation_path(ri: params[:ri]),
                alert: t("views.sign.app.settings.outs.edit.confirm_label"),
              )
              return
            end

            return if authorize_current_session_for_sign_out! == false

            prepare_sign_out_completion_notice!
            logout_current_session!(reason: "com_visitor_logout")
            redirect_to(sign_com_sign_out_completion_path(ri: params[:ri]), status: :see_other)
          end

          private

          def authorize_current_session_for_sign_out!
            return true if current_session.blank?
            return true if allowed_to?(:destroy?, current_session, context: { user: current_resource })

            head :forbidden
            false
          end
        end
      end
    end
  end
end
