# typed: false
# frozen_string_literal: true

module Acme
  module App
    # Post-login context switcher for the app surface. Shows the current account / organization /
    # avatar and the candidates the actor may switch to, and atomically changes the current context.
    # It never creates or edits entities -- that is the accounts/organizations/avatars controllers'
    # job. Requires a selected actor context (FullAccessController).
    class SwitchersController < Acme::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        @switcher = current_context

        respond_to do |format|
          format.json { render json: @switcher }
          format.html { render :show }
        end
      end

      def update
        AcmeSwitcherAuthority.switch(
          surface: :app,
          principal: current_client,
          session: current_session,
          params: switcher_params,
        )

        respond_to do |format|
          format.json { render json: { status: "switched", next: acme_app_dashboard_path(ri: params[:ri]) } }
          format.html { redirect_to(acme_app_dashboard_path(ri: params[:ri]), status: :see_other) }
        end
      rescue AcmeSwitcherAuthority::InvalidSwitch => e
        @switcher = current_context

        respond_to do |format|
          format.json { render json: { status: "invalid_switch", error: e.message }, status: :unprocessable_content }
          format.html { render :show, status: :unprocessable_content }
        end
      end

      private

      def current_context
        AcmeSwitcherAuthority.current(
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
