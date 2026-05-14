# typed: false
# frozen_string_literal: true

class Actor < ActiveSupport::CurrentAttributes
  attribute :actor, :actor_type, :account, :tenant, :surface, :session,
            :token, :domain, :preference, :trace_id, :span_id

  resets do
    self.actor = Unauthenticated.instance
    self.actor_type = :unauthenticated
    self.preference = Actor::Preference::NULL
  end

  def self.preference
    super || Actor::Preference::NULL
  end

  def self.actor
    super || Unauthenticated.instance
  end

  def self.actor_type
    super || :unauthenticated
  end

  def self.surface
    super.presence || attributes[:domain]
  end

  def self.domain
    surface
  end

  def self.user?
    actor_type == :user
  end

  def self.operator?
    actor_type == :operator
  end

  def self.visitor?
    actor_type == :visitor
  end

  def self.unauthenticated?
    actor_type == :unauthenticated
  end

  def self.authenticated?
    %i(user visitor operator).include?(actor_type)
  end

  def self.user
    actor if user?
  end

  def self.operator
    actor if operator?
  end

  def self.visitor
    actor if visitor?
  end
end
