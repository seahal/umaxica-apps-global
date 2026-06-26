# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Sign
      class OutsController < Acme::App::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::SignOidcLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        COORDINATED_LOGOUT_TRUSTED_ORIGINS = JitHostOriginEnv.trusted_origins(
          ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
          ENV.fetch("CORE_SERVICE_URL", "jpx.umaxica.app"),
          ENV.fetch("BASE_SERVICE_URL", "www-jp.umaxica.app"),
          ENV.fetch("PALM_SERVICE_URL", "palm.app.localhost"),
        ).freeze

        protect_from_forgery using: :header_only,
                             trusted_origins: COORDINATED_LOGOUT_TRUSTED_ORIGINS,
                             with: :exception,
                             only: :create,
                             if: -> { params[:logout_challenge].present? }
        skip_before_action :transparent_refresh_access_token, raise: false
        before_action only: :create do
          verify_coordinated_sign_out_post!(trusted_origins: COORDINATED_LOGOUT_TRUSTED_ORIGINS)
        end
        after_action :sign_out_notice_cache_headers!, only: %i(edit complete)

        helper_method :sign_out_completed_description
        helper_method :sign_out_confirmation_form_path

        def new
          redirect_to(sign_out_edit_path, status: :see_other)
        end

        def edit
          if params[:logout_challenge].present?
            logout_challenge = params.expect(:logout_challenge)
            @logout_transaction = AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: logout_challenge)
            warn_sign_out_event(
              "auth.sign_out.legacy_handoff.used",
              transaction: @logout_transaction,
              auto_handoff: true,
              user_confirmation_required: false,
              cleanup_performed: false,
              result: "rejected",
              reason: "get_handoff_retired",
            )
            reject_acme_coordinated_logout!("get_handoff_retired")
          else
            render_sign_out_confirmation("acme/shared/sign_outs/edit")
          end
        rescue ActiveRecord::RecordNotFound
          reject_acme_coordinated_logout!("not_found")
        end

        def create
          return continue_acme_coordinated_logout if params[:logout_challenge].present?
          return render_oidc_logout_completion if logout_browser_session_missing?

          transaction_result = issue_acme_logout_transaction!
          return render_oidc_logout_completion unless transaction_result.success?

          transaction = transaction_result.transaction
          log_sign_out_event(
            "auth.sign_out.transaction.issued",
            transaction: transaction,
            user_confirmation_required: true,
            auto_handoff: false,
            cleanup_performed: false,
            result: "issued",
          )
          prepare_sign_out_completion_notice!
          log_sign_out_event("auth.sign_out.step.started", transaction: transaction, result: "started")
          logout_current_session!(reason: "user_logout")
          log_sign_out_event(
            "auth.sign_out.step.cleaned",
            transaction: transaction,
            cleanup_performed: true,
            result: "cleaned",
          )
          issue_sign_out_notice!
          AcmeLogoutTransactionCoordinator.advance!(
            logout_challenge: transaction.logout_challenge,
            step: "origin_cleared",
          )
          log_sign_out_event(
            "auth.sign_out.step.advanced",
            transaction: transaction.reload,
            step_after: transaction.expected_step,
            redirect_target_surface: "sign",
            result: "advanced",
          )

          render_cross_origin_sign_out_handoff(
            target_url: sign_app_sign_out_url(
              host: Rails.configuration.x.boot_config.fetch(:hosts).sign_service.host,
              protocol: "https",
            ),
            transaction: transaction,
          )
        end

        def complete
          render_oidc_logout_completion
        end

        private

        def sign_out_confirmation_form_path
          sign_out_post_path
        end

        def continue_acme_coordinated_logout
          logout_challenge = params.expect(:logout_challenge)
          @logout_transaction = AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: logout_challenge)
          return reject_acme_coordinated_logout!("expired") if @logout_transaction.expired?
          return reject_acme_coordinated_logout!("wrong_step") unless
            @logout_transaction.expected_step == "acme_cleared"

          log_sign_out_event(
            "auth.sign_out.step.started",
            transaction: @logout_transaction,
            auto_handoff: true,
            user_confirmation_required: false,
            result: "started",
          )
          prepare_sign_out_completion_notice!
          logout_current_session!(reason: "user_logout")
          log_sign_out_event(
            "auth.sign_out.step.cleaned",
            transaction: @logout_transaction,
            auto_handoff: true,
            user_confirmation_required: false,
            cleanup_performed: true,
            result: "cleaned",
          )
          issue_sign_out_notice!

          advance_result = AcmeLogoutTransactionCoordinator.advance!(
            logout_challenge: @logout_transaction.logout_challenge,
            step: "acme_cleared",
          )
          transaction = advance_result.transaction || @logout_transaction
          unless advance_result.success?
            return reject_acme_coordinated_logout!(advance_result.error || "invalid_request")
          end

          log_sign_out_event(
            "auth.sign_out.step.advanced",
            transaction: transaction,
            step_after: transaction.expected_step,
            auto_handoff: true,
            user_confirmation_required: false,
            cleanup_performed: true,
            redirect_target_surface: (transaction.origin_surface == "sign") ? transaction.origin_surface : "sign",
            result: "advanced",
          )

          finalize_or_redirect_coordinated_logout!(transaction)
        rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing
          reject_acme_coordinated_logout!("not_found")
        end

        def issue_acme_logout_transaction!
          AcmeLogoutTransactionCoordinator.issue!(
            origin_surface: "acme",
            initiating_client_id: "acme-rp",
            completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
              origin_surface: "acme",
              ri: params[:ri],
              surface: sign_surface_name,
            ),
            actor_ref: current_resource.try(:public_id),
            session_ref: safe_current_session_public_id_for_logout,
            callback_state: nil,
            surface: sign_surface_name,
          )
        end

        def finalize_or_redirect_coordinated_logout!(transaction)
          if transaction.origin_surface == "sign"
            finalize_result = AcmeLogoutTransactionCoordinator.finalize!(
              logout_challenge: transaction.logout_challenge,
            )
            unless finalize_result.success?
              return reject_acme_coordinated_logout!(finalize_result.error || "invalid_request")
            end

            log_sign_out_event(
              "auth.sign_out.transaction.finalized",
              transaction: finalize_result.transaction,
              step_after: "finalized",
              auto_handoff: true,
              user_confirmation_required: false,
              cleanup_performed: true,
              redirect_target_surface: "sign",
              result: "finalized",
            )
            redirect_to_jump_url(finalize_result.transaction.completion_url, status: :see_other)
          else
            render_cross_origin_sign_out_handoff(
              target_url: sign_app_sign_out_url(
                host: Rails.configuration.x.boot_config.fetch(:hosts).sign_service.host,
                protocol: "https",
              ),
              transaction: transaction,
            )
          end
        end

        def reject_acme_coordinated_logout!(reason)
          warn_sign_out_event(
            "auth.sign_out.challenge.rejected",
            transaction: @logout_transaction,
            challenge_valid: false,
            auto_handoff: true,
            user_confirmation_required: false,
            cleanup_performed: false,
            result: "rejected",
            reason: reason,
          )
          render "sign/shared/sign_outs/unavailable", status: :unprocessable_content
        end

        def oidc_logout_completion_template
          "acme/shared/sign_outs/complete"
        end

        def logout_browser_session_missing?
          request.headers["Authorization"].blank? &&
            cookies[AuthenticationBase::REFRESH_COOKIE_KEY].blank?
        end
      end
    end
  end
end
