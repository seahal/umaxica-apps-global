# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      module Checkpoint
        class BirthdatesController < Sign::App::ApplicationController
          include Sign::Up::SequenceControllerSupport

          AUTHENTICATION_MODE = :guest

          before_action :load_sign_up_ticket
          before_action -> { authorize_sign_up_requirement_or_cleared_continue!(:clear_requirement?) }

          def update
            clear_sign_up_birthdate_requirement
          end

          private

          def clear_sign_up_birthdate_requirement
            return super unless pending_social_signup_confirmation?
            return if performed?
            return continue_after_cleared_sign_up_requirement if sign_up_requirement_cleared?(:birthdate)
            return unless validate_sign_up_checkpoint_version!
            return render_missing_social_signup_confirmation unless social_signup_confirmation_cleared?

            birthdate = sign_up_birthdate_param
            unless AgeEligibility.minimum_age_reached?(birthdate, minimum_age: 13, today: Time.zone.today)
              sign_up_session_state.age_restricted = true
              result = SignUp::Termination.call(cycle: @sign_up_ticket, event: :fail, actor_context: Actor.authn)
              return render_sign_up_result(result) unless result.success? || result.status == :failed

              render_sign_up_age_restricted
              return
            end

            create_social_signup_actor!(birthdate)
            run_sign_up_requirement_event(payload: { requirement: :birthdate })
          rescue SocialAuth::BaseError, Identity::SocialCeremony::Error
            render plain: I18n.t("errors.social_auth.provider_error"), status: :unprocessable_content
          end

          def sign_up_surface = :app

          def sign_up_ticket_class = ClientSignUpFlow

          def sign_up_sequence_session_key = :sign_app_up_sequence_id

          def pending_social_signup_confirmation?
            @sign_up_ticket&.social_entry_method? &&
              @sign_up_ticket&.principal_id.blank? &&
              social_signup_evidence.present?
          end

          def social_signup_confirmation_cleared?
            @sign_up_ticket.requirement_cleared?(:confirmation)
          end

          def render_missing_social_signup_confirmation
            render plain: "social_signup_confirmation_required", status: :unprocessable_content
          end

          def create_social_signup_actor!(birthdate)
            AppTicketRecord.connected_to(role: :writing) do
              @sign_up_ticket.with_cycle_lock do
                @sign_up_ticket.reload
                return if @sign_up_ticket.principal_id.present?

                candidate = consume_social_signup_candidate!
                result = SocialAuth::SignupFinalizer.call(
                  auth_hash: candidate.auth_hash,
                  birthdate: birthdate,
                )
                identity = result.fetch(:identity)
                user = result.fetch(:user)

                @sign_up_ticket.update!(
                  principal_id: user.id,
                  pending_contact_type: "social_identity",
                  pending_contact_id: identity.id,
                  social_provider: SocialIdentifiable.normalize_provider(identity.provider),
                )
              end
            end
          end

          def consume_social_signup_candidate!
            evidence = social_signup_evidence
            candidate = Identity::SocialCeremony::CandidateStore.consume!(evidence.fetch("candidate_ref"))
            raise Identity::SocialCeremony::Error, "candidate digest mismatch" unless
              candidate.digest.to_s == evidence.fetch("candidate_digest").to_s
            raise Identity::SocialCeremony::Error, "candidate surface mismatch" unless candidate.surface.to_s == "app"
            raise Identity::SocialCeremony::Error, "candidate actor mismatch" unless
              candidate.actor_ref.to_s == @sign_up_ticket.public_id.to_s
            raise Identity::SocialCeremony::Error, "candidate session mismatch" unless
              candidate.session_ref.to_s == @sign_up_ticket.public_id.to_s
            raise Identity::SocialCeremony::Error, "candidate transaction mismatch" unless
              candidate.transaction_id.to_s == @sign_up_ticket.public_id.to_s
            raise Identity::SocialCeremony::Error,
                  "candidate operation mismatch" unless candidate.operation.to_s == "signup"

            provider = SocialIdentifiable.normalize_provider(candidate.provider)
            uid = SocialAuth::UidExtractor.call(auth_hash: candidate.auth_hash)
            raise Identity::SocialCeremony::Error,
                  "candidate provider mismatch" unless provider == @sign_up_ticket.social_provider
            raise Identity::SocialCeremony::Error,
                  "candidate provider evidence mismatch" unless provider == evidence.fetch("provider")
            raise Identity::SocialCeremony::Error, "candidate uid mismatch" unless
              pending_social_signup_uid_digest(provider: provider, uid: uid) == evidence.fetch("uid_digest")

            SocialAuth::VerifiedProviderAssertion.call(
              auth_hash: candidate.auth_hash,
              expected_provider: candidate.provider,
            )
            candidate
          end

          def social_signup_evidence
            value = @sign_up_ticket&.completed_requirements&.fetch("social_signup", nil)
            value if value.is_a?(Hash)
          end

          def pending_social_signup_uid_digest(provider:, uid:)
            OpenSSL::HMAC.hexdigest(
              "SHA256",
              Rails.application.secret_key_base,
              [provider, uid].map(&:to_s).join(":"),
            )
          end
        end
      end
    end
  end
end
