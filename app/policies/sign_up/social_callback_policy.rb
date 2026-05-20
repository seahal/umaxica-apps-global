# typed: false
# frozen_string_literal: true

module SignUp
  class SocialCallbackPolicy < BasePolicy
    def start_social_callback?
      mutable_ticket? && app_social_ticket? && at_step?("start")
    end

    def complete_social_callback?
      mutable_ticket? && app_social_ticket? && at_step?("social_callback")
    end

    private

    def app_social_ticket?
      surface == :app && RequirementRegistry.for_ticket(ticket, surface: surface).social?
    rescue ArgumentError
      false
    end
  end
end
