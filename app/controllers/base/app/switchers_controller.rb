# typed: false
# frozen_string_literal: true

module Base
  module App
    # Post-login context switcher for the app surface. Selector owns the pre-access ceremony and
    # commits the first selected context; switcher only runs after that full-access gate is open,
    # shows the current account / organization / avatar, and atomically changes the current
    # context. It never creates or edits entities -- that is the accounts/organizations/avatars
    # controllers' job. Requires a selected actor context (FullAccessController).
    class SwitchersController < Base::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        authorize!(current_client, to: :show?)
        @switcher = current_context

        respond_to do |format|
          format.json { render json: @switcher }
          format.html { render :show }
        end
      end

      def update
        authorize!(current_client, to: :update?)
        BaseSwitcherAuthority.switch(
          surface: :app,
          principal: current_client,
          session: current_session,
          params: switcher_params,
        )

        respond_to do |format|
          format.json { render json: { status: "switched", next: base_app_dashboard_path(ri: params[:ri]) } }
          format.html { redirect_to(base_app_dashboard_path(ri: params[:ri]), status: :see_other) }
        end
      rescue BaseSwitcherAuthority::InvalidSwitch => e
        @switcher = current_context

        respond_to do |format|
          format.json { render json: { status: "invalid_switch", error: e.message }, status: :unprocessable_content }
          format.html { render :show, status: :unprocessable_content }
        end
      end

      private

      def current_context
        BaseSwitcherAuthority.current(
          surface: :app, principal: current_client, session: current_session,
        )
      end

      def switcher_params
        params.permit(
          :account_public_id, :organization_public_id, :organization_unit_public_id,
          :collective_public_id, :collective_unit_public_id, :avatar_public_id,
        ).to_h.symbolize_keys
      end
    end
  end
end
