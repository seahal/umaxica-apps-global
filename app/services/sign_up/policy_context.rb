# typed: false
# frozen_string_literal: true

module SignUp
  SURFACES = %i(app com).freeze

  PolicyContext =
    Data.define(:surface, :actor_authentication, :ticket, :step, :entry_method) do
      def self.build(surface:, actor_authentication:, ticket:, step: nil, entry_method: nil)
        normalized_surface = surface.to_sym
        raise ArgumentError, "unknown sign-up surface: #{surface.inspect}" unless SURFACES.include?(normalized_surface)

        new(
          surface: normalized_surface,
          actor_authentication: actor_authentication,
          ticket: ticket,
          step: step || ticket&.step,
          entry_method: entry_method || ticket&.entry_method,
        )
      end
    end
end
