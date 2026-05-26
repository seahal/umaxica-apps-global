# typed: false
# frozen_string_literal: true

module SignIn
  class SelectorParticipant
    class Error < StandardError; end

    class InvalidCycle < Error; end

    class SelectionConflict < Error; end

    Result = Struct.new(:cycle, :candidate, :status, keyword_init: true)

    def initialize(cycle:, actor:, authn_public_id: nil, resolver: nil)
      @cycle = cycle
      @actor = actor
      @authn_public_id = authn_public_id
      @resolver = resolver || ActivationCandidateResolver.new(cycle: cycle, actor: actor)
    end

    def auto_commit_single!
      cycle.class.transaction do
        cycle.lock!
        ensure_selector_cycle!

        candidates = resolver.candidates
        raise InvalidCycle, "selector candidate is required" unless candidates.one?

        candidate = candidates.first
        cycle.advance_sign_in_to_session_issuance!(changes: selection_changes(candidate))
        Result.new(cycle: cycle, candidate: candidate, status: :auto_committed)
      end
    end

    private

    attr_reader :cycle, :actor, :authn_public_id, :resolver

    def ensure_selector_cycle!
      raise InvalidCycle, "sign-in cycle is not pending selector" unless cycle.sign_in_selector_pending?
      raise InvalidCycle, "sign-in cycle is expired" if cycle.expired?
      raise InvalidCycle, "sign-in cycle is not bound to an actor" if cycle.principal_id.blank?
      raise InvalidCycle, "actor does not match sign-in cycle" unless resolved_actor&.id == cycle.principal_id
      raise InvalidCycle, "actor class does not match sign-in cycle" unless actor_class_matches?
    end

    def actor_class_matches?
      case cycle
      when ClientSignInCycle then resolved_actor.is_a?(Client)
      when VisitorSignInCycle then resolved_actor.is_a?(Visitor)
      when OperatorSignInCycle then resolved_actor.is_a?(Operator)
      else false
      end
    end

    def resolved_actor
      @resolved_actor ||=
        actor || cycle.principal
    end

    def selection_changes(candidate)
      changes = {}
      changes[:selected_region_id] = numeric_or_nil(candidate.region) if cycle.has_attribute?(:selected_region_id)
      changes[:selected_persona_id] = numeric_or_nil(candidate.persona) if cycle.has_attribute?(:selected_persona_id)
      changes[:selector_completed_at] = Time.current if cycle.has_attribute?(:selector_completed_at)
      changes
    end

    def numeric_or_nil(value)
      Integer(value, 10)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
