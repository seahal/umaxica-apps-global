# typed: false
# frozen_string_literal: true

module SignUp
  FinalizationContext =
    Data.define(:surface, :actor_authentication, :ticket, :pending_actor, :completed_requirements) do
      def self.build(surface:, actor_authentication:, ticket:, pending_actor:, completed_requirements: nil)
        registry = RequirementRegistry.for_ticket(ticket, surface: surface)
        requirements = completed_requirements || ticket.completed_requirements
        missing = registry.missing_requirements(requirements)
        raise ArgumentError, "missing sign-up requirements: #{missing.join(", ")}" if missing.any?

        new(
          surface: surface.to_sym,
          actor_authentication: actor_authentication,
          ticket: ticket,
          pending_actor: pending_actor,
          completed_requirements: requirements,
        )
      end
    end
end
