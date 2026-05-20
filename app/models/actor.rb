# typed: false
# frozen_string_literal: true

class Actor < ActiveSupport::CurrentAttributes
  Context =
    Data.define(
      :actor,
      :actor_type,
      :account,
      :tenant,
      :tld,
      :session,
      :token,
      :authentication,
      :configuration,
      :preference,
      :trace_id,
      :span_id,
    ) do
      def self.empty
        new(
          actor: Unauthenticated.instance,
          actor_type: :unauthenticated,
          account: nil,
          tenant: nil,
          tld: nil,
          session: nil,
          token: nil,
          authentication: Actor::Authentication::NULL,
          configuration: Actor::Configuration::NULL,
          preference: Actor::Preference::NULL,
          trace_id: nil,
          span_id: nil,
        )
      end
    end

  attribute :context

  resets do
    self.context = Context.empty
  end

  class << self
    def context
      super || Context.empty
    end

    def update(**attributes)
      self.context = context.with(**normalize_context_attributes(attributes))
    end

    def clear
      reset
    end

    def actor = context.actor || Unauthenticated.instance

    def actor=(value)
      update(actor: value)
    end

    def actor_type = context.actor_type || :unauthenticated

    def actor_type=(value)
      update(actor_type: value)
    end

    def whoami = actor_type

    delegate :account, to: :context

    def account=(value)
      update(account: value)
    end

    delegate :tenant, to: :context

    def tenant=(value)
      update(tenant: value)
    end

    delegate :tld, to: :context

    def tld=(value)
      update(tld: value)
    end

    delegate :session, to: :context

    def session=(value)
      update(session: value)
    end

    delegate :token, to: :context

    def token=(value)
      update(token: value)
    end

    def authentication = context.authentication || Actor::Authentication::NULL

    def authentication=(value)
      update(authentication: value)
    end

    def configuration = context.configuration || Actor::Configuration::NULL

    def configuration=(value)
      update(configuration: value)
    end

    def preference = context.preference || Actor::Preference::NULL

    def preference=(value)
      update(preference: value)
    end

    delegate :trace_id, to: :context

    def trace_id=(value)
      update(trace_id: value)
    end

    delegate :span_id, to: :context

    def span_id=(value)
      update(span_id: value)
    end

    def client?
      actor_type == :client
    end

    def operator?
      actor_type == :operator
    end

    def visitor?
      actor_type == :visitor
    end

    def unauthenticated?
      actor_type == :unauthenticated
    end

    def authenticated?
      %i(client visitor operator).include?(actor_type)
    end

    alias signed_in? authenticated?

    def signed_up?
      return false unless authenticated?
      return true if actor.respond_to?(:persisted?) && actor.persisted?

      actor.respond_to?(:id) && actor.id.present?
    end

    def client
      actor if client?
    end

    def operator
      actor if operator?
    end

    def visitor
      actor if visitor?
    end

    private

    def normalize_context_attributes(attributes)
      attributes.each_with_object({}) do |(key, value), normalized|
        normalized[key] = normalize_context_value(key, value)
      end
    end

    def normalize_context_value(key, value)
      case key
      when :preference
        value || Actor::Preference::NULL
      when :authentication
        value || Actor::Authentication::NULL
      when :configuration
        value || Actor::Configuration::NULL
      when :token
        immutable_token(value)
      else
        value
      end
    end

    def immutable_token(value)
      case value
      when Hash
        value.transform_values { |entry| immutable_token(entry) }.freeze
      when Array
        value.map { |entry| immutable_token(entry) }.freeze
      else
        value
      end
    end
  end
end
