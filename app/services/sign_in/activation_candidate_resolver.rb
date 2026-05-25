# typed: false
# frozen_string_literal: true

module SignIn
  class ActivationCandidateResolver
    Candidate = Struct.new(:region, :persona, keyword_init: true)

    def initialize(cycle:, actor:)
      @cycle = cycle
      @actor = actor
    end

    def candidates
      return [] unless resolved_actor

      [Candidate.new(region: default_region, persona: default_persona)]
    end

    private

    attr_reader :cycle, :actor

    def resolved_actor
      @resolved_actor ||=
        actor || case cycle
                 when ClientSignInCycle then Client.find_by(id: cycle.principal_id)
                 when VisitorSignInCycle then Visitor.find_by(id: cycle.principal_id)
                 when OperatorSignInCycle then Operator.find_by(id: cycle.principal_id)
                 end
    end

    def default_region
      Actor.preferences&.region.presence || "JP"
    rescue StandardError
      "JP"
    end

    def default_persona
      resolved_actor.class.name
    end
  end
end
