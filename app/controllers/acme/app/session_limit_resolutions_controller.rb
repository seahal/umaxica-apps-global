# typed: false
# frozen_string_literal: true

module Acme
  module App
    class SessionLimitResolutionsController < Acme::App::ApplicationController
      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      before_action :load_resolution

      def show
        return render_invalid_resolution unless @resolution

        load_session_inventory
      end

      def update
        return render_invalid_resolution unless @resolution

        token = selected_token
        unless token_belongs_to_actor?(token)
          @form_error = "The selected session could not be revoked."
          load_session_inventory
          return render :show, status: :unprocessable_content
        end

        @resolution.mark_session_selected!(session_ref: params[:session_ref])
        AuthenticationSelectedSessionRevoker.call(
          owner: @actor,
          token: token,
          reason: "session_limit_resolution_selected_revoke",
        )

        if hard_reject_still_applies?
          @form_notice = "Session capacity is still full. Revoke another session to continue."
          load_session_inventory
          return render :show, status: :unprocessable_content
        end

        resume_authorization_after_resolution
      end

      def destroy
        return render_invalid_resolution unless @resolution

        @resolution.cancel!
        redirect_to(
          sign_app_sign_in_url(host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost")),
          allow_other_host: cross_host_redirect_allowed?,
          status: :see_other,
        )
      end

      private

      def load_resolution
        @resolution_challenge = params[:resolution_challenge].to_s
        @resolution = ClientSessionLimitResolutionTransaction.find_active_by_challenge(@resolution_challenge)
        return unless @resolution

        @actor = Client.find_by(public_id: @resolution.actor_ref)
        @oidc_transaction = @resolution.oidc_authorization_transaction
      end

      def render_invalid_resolution
        render plain: "This session-limit resolution link is invalid or expired.", status: :gone
      end

      def load_session_inventory
        @sessions =
          AppTicketRecord.connected_to(role: :writing) do
            ClientToken.not_revoked
              .where(user_id: @actor.id, rotated_at: nil)
              .order(created_at: :desc)
              .to_a
          end
      end

      def selected_token
        SessionLimitResolutionTokenRef.find_client_token(params[:session_ref])
      end

      def token_belongs_to_actor?(token)
        token.present? && @actor.present? && token.user_id == @actor.id && token.currently_usable?
      end

      def hard_reject_still_applies?
        AppTicketRecord.connected_to(role: :writing) do
          ClientToken.not_revoked.where(user_id: @actor.id, rotated_at: nil).count >=
            ClientToken::MAX_TOTAL_SESSIONS_PER_USER
        end
      end

      def resume_authorization_after_resolution
        @oidc_transaction.consume!
        @resolution.finalize!
        issue_authorization_code!
      end

      def issue_authorization_code!
        result = ::OidcAuthorizeService.call(
          params: @oidc_transaction.authorize_params,
          resource: @actor,
          auth_method: @oidc_transaction.auth_method,
          acr: @oidc_transaction.acr,
        )

        if result.success?
          redirect_to_jump_url(result.redirect_url)
        else
          render json: { error: result.error, error_description: result.error_description },
                 status: :bad_request
        end
      end
    end
  end
end
