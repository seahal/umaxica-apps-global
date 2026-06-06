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
      :authn,
      :authz,
      :configuration,
      :preferences,
      :selection,
      :step_up,
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
          authn: Actor::Authentication::NULL,
          authz: Actor::Authz::NULL,
          configuration: Actor::Configuration::NULL,
          preferences: Actor::Preference::NULL,
          selection: Actor::SelectedContext::NULL,
          step_up: Actor::StepUp::NULL,
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

    def install_context!(**attributes)
      update(**attributes)
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

    def authn = context.authn || Actor::Authentication::NULL

    def authn=(value)
      update(authn: value)
    end

    def authz = context.authz || Actor::Authz::NULL

    def authz=(value)
      update(authz: value)
    end

    def configuration = context.configuration || Actor::Configuration::NULL

    def configuration=(value)
      update(configuration: value)
    end

    def preferences = context.preferences || Actor::Preference::NULL

    def preferences=(value)
      update(preferences: value)
    end

    def selection = context.selection || Actor::SelectedContext::NULL

    def selection=(value)
      update(selection: value)
    end

    def step_up = context.step_up || Actor::StepUp::NULL

    def step_up=(value)
      update(step_up: value)
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

    # Spec-facing predicate aliases. The canonical names in this codebase are
    # unauthenticated?/client?/operator?; these mirror the actor-context vocabulary
    # (anonymous/user/staff) without introducing new state.
    def anonymous? = unauthenticated?

    def user? = client?

    def staff? = operator?

    # Step-up freshness, derived from the resolved step_up context. StepUp::Resolver
    # already enforces TTL + scope/aal/binding, so a satisfied step_up is a fresh one.
    def step_up_fresh? = step_up.satisfied?

    # True when the current request demands a step-up that is not yet satisfied.
    # When verification is not required, step_up is Actor::StepUp::NULL (scope nil),
    # so this is false.
    def requires_step_up?
      step_up.scope.present? && !step_up.satisfied?
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
        normalized[normalize_context_key(key)] = normalize_context_value(key, value)
      end
    end

    def normalize_context_key(key)
      key
    end

    # FIXME: cofniguration has a lot of subdomain stuff that needs to be cleaned up
    # Actor.configuration.apex.one = 1
    # Actor.configuration.sign.two = 2
    # Actor.configuration.core.three = 3
    def normalize_context_value(key, value)
      case key
      when :preferences
        value || Actor::Preference::NULL
      when :authn
        value || Actor::Authentication::NULL
      when :authz
        value || Actor::Authz::NULL
      when :step_up
        value || Actor::StepUp::NULL
      when :configuration
        value || Actor::Configuration::NULL
      when :selection
        value || Actor::SelectedContext::NULL
      else
        value
      end
    end
  end
end
