# typed: false
# frozen_string_literal: true

class Jumper < ActiveSupport::CurrentAttributes
  include CurrentActor

  attribute :actor, :actor_type, :domain

  resets do
    self.actor = Unauthenticated.instance
    self.actor_type = :unauthenticated
  end

  def self.actor
    super || Unauthenticated.instance
  end

  def self.actor_type
    super || :unauthenticated
  end
end
