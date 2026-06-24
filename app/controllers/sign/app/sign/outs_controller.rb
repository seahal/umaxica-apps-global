# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      class OutsController < ::Sign::App::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::OidcRpLogoutLauncher

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        COORDINATED_LOGOUT_TRUSTED_ORIGINS = JitHostOriginEnv.trusted_origins(
          ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
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
        helper_method :sign_out_completed_description
        helper_method :sign_out_confirmation_form_path

        after_action :sign_out_notice_cache_headers!, only: %i(edit complete)

        def new
          redirect_to(sign_out_edit_path, status: :see_other)
        end

        def edit
          if params[:logout_challenge].present?
            logout_challenge = params.expect(:logout_challenge)
            @logout_transaction = AcmeLogoutTransactionService.find_by!(logout_challenge: logout_challenge)
            warn_sign_out_event(
              "auth.sign_out.legacy_handoff.used",
              transaction: @logout_transaction,
              auto_handoff: true,
              user_confirmation_required: false,
              cleanup_performed: false,
              result: "rejected",
              reason: "get_handoff_retired",
            )
            reject_sign_coordinated_logout!("get_handoff_retired")
          else
            render_sign_out_confirmation("sign/shared/sign_outs/edit")
          end
        rescue ActiveRecord::RecordNotFound
          reject_sign_coordinated_logout!("not_found")
        end

        def create
          return continue_acme_coordinated_logout if params[:logout_challenge].present?

          launch_oidc_rp_logout!(
            client_id: "sign-rp",
            issuer_resource_type: "client",
            token_issuer: "client",
          )
        end

        def complete
          complete_oidc_rp_logout!
        end

        private

        def sign_out_confirmation_form_path
          sign_out_post_path
        end

        def continue_acme_coordinated_logout
          transaction = AcmeLogoutTransactionService.find_by!(logout_challenge: params.expect(:logout_challenge))
          @logout_transaction = transaction
          return reject_sign_coordinated_logout!("expired") if transaction.expired?
          return reject_sign_coordinated_logout!("wrong_step") unless transaction.expected_step == "sign_cleared"

          advanced_transaction = cleanup_and_advance_sign_logout!(transaction)

          finalize_result = AcmeLogoutTransactionService.finalize!(
            logout_challenge: advanced_transaction.logout_challenge,
          )
          unless finalize_result.success?
            return reject_sign_coordinated_logout!(finalize_result.error || "invalid_request")
          end

          log_sign_out_event(
            "auth.sign_out.transaction.finalized",
            transaction: finalize_result.transaction,
            step_after: "finalized",
            auto_handoff: true,
            user_confirmation_required: false,
            cleanup_performed: true,
            redirect_target_surface: finalize_result.transaction.origin_surface,
            result: "finalized",
          )
          redirect_to_jump_url(coordinated_completion_redirect_url(finalize_result.transaction), status: :see_other)
        rescue ActiveRecord::RecordNotFound, ArgumentError, ActionController::ParameterMissing
          reject_sign_coordinated_logout!("not_found")
        end

        def cleanup_and_advance_sign_logout!(transaction)
          log_sign_out_event(
            "auth.sign_out.step.started",
            transaction: transaction,
            auto_handoff: true,
            user_confirmation_required: false,
            result: "started",
          )
          logout_current_session!(reason: "user_logout")
          log_sign_out_event(
            "auth.sign_out.step.cleaned",
            transaction: transaction,
            auto_handoff: true,
            user_confirmation_required: false,
            cleanup_performed: true,
            result: "cleaned",
          )
          issue_sign_out_notice!

          advance_result = AcmeLogoutTransactionService.advance!(
            logout_challenge: transaction.logout_challenge,
            step: "sign_cleared",
          )
          unless advance_result.success?
            return reject_sign_coordinated_logout!(advance_result.error || "invalid_request")
          end

          advanced_transaction = advance_result.transaction || transaction
          log_sign_out_event(
            "auth.sign_out.step.advanced",
            transaction: advanced_transaction,
            step_after: advanced_transaction.expected_step,
            auto_handoff: true,
            user_confirmation_required: false,
            cleanup_performed: true,
            result: "advanced",
          )

          advanced_transaction
        end

        def reject_sign_coordinated_logout!(reason)
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

        def coordinated_completion_redirect_url(transaction)
          return transaction.completion_url unless transaction.origin_surface == "palm"

          uri = URI.parse(transaction.completion_url)
          query = Rack::Utils.parse_nested_query(uri.query.to_s)
          query["logout_challenge"] = transaction.logout_challenge
          query["state"] = transaction.callback_state if transaction.callback_state.present?
          uri.query = query.to_query
          uri.to_s
        rescue URI::InvalidURIError
          transaction.completion_url
        end
      end
    end
  end
end
