# typed: false
# frozen_string_literal: true

module CurrentActor
  extend ActiveSupport::Concern

  class_methods do
    def actor
      super || Unauthenticated.instance
    end

    def actor_type
      super || :unauthenticated
    end

    def user?
      actor_type == :user
    end

    def staff?
      actor_type == :staff
    end

    def customer?
      actor_type == :customer
    end

    def unauthenticated?
      actor_type == :unauthenticated
    end

    def authenticated?
      %i(user customer staff).include?(actor_type)
    end

    def user
      actor if user?
    end

    def staff
      actor if staff?
    end

    def customer
      actor if customer?
    end
  end
end
