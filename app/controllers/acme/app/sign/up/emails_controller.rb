# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Sign
      module Up
        class EmailsController < Acme::App::ApplicationController
          AUTHENTICATION_MODE = :open

          declare_authentication_mode! :open, only: :completion

          def completion
            completion_context = current_completion_context
            cycle = current_sign_up_cycle(completion_context)
            return render_missing_sign_up_completion unless cycle
            return render_missing_sign_up_completion unless cycle.pending_contact_type.to_s == "email"

            actor = current_sign_up_actor(cycle, completion_context)
            return render_missing_sign_up_completion unless actor

            IdentityGraphProvisioner.call!(surface: :app, principal: actor)
            session_result = establish_signed_in_session!(
              actor,
              pt: completion_pt(cycle),
              ri: params[:ri],
              auth_method: "email",
              audit_context: { auth_method: "email", flow: "sign_up", sign_up_flow_id: cycle.public_id },
              bootstrap_actor: true,
            )
            sign_in_result = sign_in_result_from_session_result(session_result, actor: actor)

            return handle_sign_up_completion_failure(sign_in_result) unless
              sign_in_result.status == :success || sign_in_result.status == :session_limit_pending

            complete_sign_up_flow!(cycle, sign_in_result)
            SignUpSessionState.for(session, surface: :app).clear_all!
            redirect_to_jump_url(
              sign_in_result.redirect_to,
              status: :see_other,
            )
          rescue StandardError => e
            Rails.logger.info(
              JitLogEvent.format(
                "acme.email_signup_completion_failed",
                reason: e.class.name,
              ),
            )
            render_missing_sign_up_completion
          end

          private

          def current_completion_context
            {
              "cycle_public_id" => current_completion_cycle&.public_id,
              "actor_public_id" => current_completion_actor&.public_id,
              "email_public_id" => current_completion_email&.public_id,
            }.compact
          end

          def current_sign_up_cycle(completion_context = nil)
            cycle = SignUpCycleLocator.new(session, surface: :app, cycle_class: ClientSignUpFlow).current
            return cycle if cycle
            return nil unless completion_context

            current_completion_cycle
          end

          def current_sign_up_actor(cycle, completion_context = nil)
            if cycle.principal_id.present?
              return Client.find_by(id: cycle.principal_id)
            end

            return nil unless completion_context

            current_completion_actor
          end

          def current_completion_cycle
            token = params[:completion_token].to_s
            return if token.blank?

            ClientSignUpFlow.find_signed(token, purpose: :email_signup_completion)
          end

          def current_completion_actor
            token = params[:completion_actor_token].to_s
            return if token.blank?

            Client.find_signed(token, purpose: :email_signup_completion)
          end

          def current_completion_email
            token = params[:completion_email_token].to_s
            return if token.blank?

            ClientEmail.find_signed(token, purpose: :email_signup_completion)
          end

          def completion_pt(cycle)
            params[:pt].presence || cycle.return_to.presence
          end

          def complete_sign_up_flow!(cycle, sign_in_result)
            AppTicketRecord.connected_to(role: :writing) do
              cycle.with_cycle_lock do
                cycle.reload
                finalization_result = finalize_sign_up_side_effect!(cycle)
                raise StandardError, "sign up finalization side effect failed" unless
                  finalization_result == :accepted

                finalize = SignUpStateMachine.call(
                  ticket: cycle,
                  event: :finalize,
                  actor_context: Actor.authn,
                  payload: { finalization_result: finalization_result },
                )
                raise StandardError, "sign up finalization failed" unless finalize.success?

                handoff = SignUpStateMachine.call(
                  ticket: cycle,
                  event: :handoff_to_sign_in,
                  actor_context: Actor.authn,
                  payload: {
                    sign_in_handoff_status: :accepted,
                    sign_in_handoff: sign_in_result.status,
                  },
                )
                raise StandardError, "sign up handoff failed" unless handoff.success?

                complete = SignUpStateMachine.call(
                  ticket: cycle,
                  event: :complete,
                  actor_context: Actor.authn,
                )
                raise StandardError, "sign up completion failed" unless complete.success?
              end
            end
          end

          def finalize_sign_up_side_effect!(cycle)
            actor = current_sign_up_actor(cycle)
            return :failed unless actor

            case cycle.pending_contact_type.to_s
            when "email"
              Client.transaction do
                actor.update!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP) if
                  actor.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP
              end
            else
              return :failed
            end

            :accepted
          rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
            :failed
          end

          def handle_sign_up_completion_failure(sign_in_result)
            if sign_in_result.mfa_required?
              return redirect_to(sign_in_result.redirect_to, status: :see_other)
            end

            if sign_in_result.session_limit_pending?
              return redirect_to(sign_in_result.redirect_to, status: :see_other)
            end

            render_missing_sign_up_completion
          end

          def render_missing_sign_up_completion
            render plain: "ticket is required", status: :unprocessable_content
          end
        end
      end
    end
  end
end
