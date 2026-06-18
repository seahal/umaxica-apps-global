# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Sign
      class OutsController < Acme::Org::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        before_action :authenticate!, only: %i(edit create destroy)
        helper_method :sign_out_completed_description

        def show
          render "acme/shared/sign_outs/edit"
        end

        def edit
          redirect_to(acme_org_sign_out_path(ri: params[:ri]), status: :see_other)
        end

        def create
          unless ActiveModel::Type::Boolean.new.cast(params[:confirm])
            redirect_to(
              acme_org_sign_out_path(ri: params[:ri]),
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

          logout_current_session!(reason: "org_operator_logout")
          return render_invalid_return_target! if raw_pt.present? && destination.blank?
          return redirect_to_pt_destination!(destination) if destination.present?

          redirect_to_signed_out_page!
        end

        def authorize_current_session_for_sign_out!
          return true if current_session.blank?
          return true if allowed_to?(:destroy?, current_session, context: { user: current_resource })

          head :forbidden
          false
        end

        def redirect_to_signed_out_page!
          redirect_to(
            sign_org_root_url(ri: params[:ri], host: ENV.fetch("ID_STAFF_URL", "id.org.localhost")),
            allow_other_host: cross_host_redirect_allowed?,
            status: :see_other,
          )
        end
      end
    end
  end
end
