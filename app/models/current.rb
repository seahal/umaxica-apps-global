# typed: false
# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  include CurrentActor

  attribute :actor, :actor_type, :session, :token, :domain, :preference,
            :trace_id, :span_id

  resets do
    self.actor = Unauthenticated.instance
    self.actor_type = :unauthenticated
    self.preference = Current::Preference::NULL
  end

  def self.preference
    super || Current::Preference::NULL
  end

  def self.actor
    super || Unauthenticated.instance
  end

  def self.actor_type
    super || :unauthenticated
  end
end
