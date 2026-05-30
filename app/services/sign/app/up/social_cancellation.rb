# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      class SocialCancellation
        SUPPORTED_PROVIDERS = {
          "apple" => ClientAppleIdentity,
          "google" => ClientGoogleIdentity,
        }.freeze

        def self.call(...)
          new(...).call
        end

        def initialize(cycle:)
          @cycle = cycle
        end

        def call
          return SignUp::Result.build(status: :blocked, ticket: cycle, errors: ["ticket is required"]) unless cycle
          return SignUp::Result.build(
            status: :blocked, ticket: cycle,
            errors: ["not a social sign-up"],
          ) unless social_cycle?

          actor = Client.find_by(id: cycle.principal_id)
          return SignUp::Result.build(
            status: :blocked, ticket: cycle,
            errors: ["pending actor is required"],
          ) unless pending_actor?(actor)

          identity = identity_class.find_by(id: cycle.pending_contact_id)
          return SignUp::Result.build(
            status: :blocked, ticket: cycle,
            errors: ["pending social identity is required"],
          ) unless pending_identity?(
            identity, actor,
          )

          SignUp::Cancellation.call(cycle: cycle, actor_context: Actor.authn)
        end

        private

        attr_reader :cycle

        def social_cycle?
          cycle.pending_contact_type == "social_identity" &&
            SUPPORTED_PROVIDERS.key?(normalized_provider) &&
            cycle.social_entry_method?
        end

        def normalized_provider
          cycle.social_provider.presence || cycle.entry_method
        end

        def identity_class
          SUPPORTED_PROVIDERS.fetch(normalized_provider)
        end

        def pending_actor?(actor)
          actor&.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP
        end

        def pending_identity?(identity, actor)
          identity&.user_id == actor.id
        end
      end
    end
  end
end
