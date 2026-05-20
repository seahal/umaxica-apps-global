# typed: false
# frozen_string_literal: true

module SignUp
  RequirementContext =
    Data.define(
      :surface,
      :actor_authentication,
      :ticket,
      :requirement,
      :pending_actor,
      :pending_contact,
    ) do
      def self.build(
        surface:,
        actor_authentication:,
        ticket:,
        requirement:,
        pending_actor: nil,
        pending_contact: nil
      )
        normalized_requirement = requirement.to_sym
        registry = RequirementRegistry.for_ticket(ticket, surface: surface)
        unless registry.requirement?(normalized_requirement)
          raise ArgumentError, "requirement #{requirement.inspect} does not belong to #{surface}/#{ticket.entry_method}"
        end

        new(
          surface: surface.to_sym,
          actor_authentication: actor_authentication,
          ticket: ticket,
          requirement: normalized_requirement,
          pending_actor: pending_actor,
          pending_contact: pending_contact,
        )
      end
    end
end
