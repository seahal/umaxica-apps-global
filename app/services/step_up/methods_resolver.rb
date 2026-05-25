# typed: false
# frozen_string_literal: true

module StepUp
  class MethodsResolver
    Result = Data.define(:available, :configured)

    def self.call(actor:, ticket:, supported_methods:)
      new(actor: actor, ticket: ticket, supported_methods: supported_methods).call
    end

    def initialize(actor:, ticket:, supported_methods:)
      @actor = actor
      @ticket = ticket
      @supported_methods = supported_methods
    end

    def call
      return Result.new(available: [], configured: []) if actor.blank?

      supported = Array(supported_methods)
      Result.new(
        available: StepUp::AvailableMethods.call(actor, ticket: ticket) & supported,
        configured: StepUp::ConfiguredMethods.call(actor) & supported,
      )
    end

    private

    attr_reader :actor, :ticket, :supported_methods
  end
end
