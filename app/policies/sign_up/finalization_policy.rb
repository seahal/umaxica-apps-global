# typed: false
# frozen_string_literal: true

module SignUp
  class FinalizationPolicy < BasePolicy
    def finalize?
      mutable_ticket? &&
        at_step?("checkpoint") &&
        pending_actor_matches? &&
        all_requirements_clear?
    end

    def handoff_to_sign_in?
      mutable_ticket? && at_step?("finalized") && pending_actor_matches?
    end

    private

    def all_requirements_clear?
      RequirementRegistry.for_ticket(
        ticket,
        surface: surface,
      ).missing_requirements(context.completed_requirements).empty?
    rescue ArgumentError
      false
    end
  end
end
