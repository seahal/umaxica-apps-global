# typed: false
# frozen_string_literal: true

module SignIn
  class SessionIssuer
    class Error < StandardError; end

    class InvalidCycle < Error; end

    class Replay < Error; end

    class ActorMismatch < Error; end

    Result = Struct.new(:cycle, :token, :refresh_token, keyword_init: true)

    SURFACES = {
      ClientSignInCycle => {
        actor_class: Client,
        token_class: ClientToken,
        foreign_key: :user_id,
      },
      VisitorSignInCycle => {
        actor_class: Visitor,
        token_class: VisitorToken,
        foreign_key: :visitor_id,
      },
      OperatorSignInCycle => {
        actor_class: Operator,
        token_class: OperatorToken,
        foreign_key: :staff_id,
      },
    }.freeze

    def initialize(cycle:, actor:, dpop_jkt: nil)
      @cycle = cycle
      @actor = actor
      @dpop_jkt = dpop_jkt
    end

    def call
      metadata = surface_metadata
      ensure_actor_class!(metadata)

      cycle.class.transaction do
        cycle.lock!
        ensure_issuable_cycle!
        ensure_actor_binding!

        token = create_token!(metadata)
        refresh_token = token.rotate_refresh_token!
        cycle.update!(token: token)
        cycle.advance_sign_in_to_checkpoint!

        Result.new(cycle: cycle, token: token, refresh_token: refresh_token)
      end
    end

    private

    attr_reader :cycle, :actor, :dpop_jkt

    def surface_metadata
      SURFACES.fetch(cycle.class) { raise InvalidCycle, "unsupported sign-in cycle" }
    end

    def ensure_actor_class!(metadata)
      return if actor.is_a?(metadata.fetch(:actor_class))

      raise ActorMismatch, "actor does not match sign-in cycle surface"
    end

    def ensure_issuable_cycle!
      raise Replay, "sign-in cycle already issued a token" if cycle.token_id.present?
      raise InvalidCycle, "sign-in cycle is not ready to issue a session" unless cycle.sign_in_session_issuance_pending?
      raise InvalidCycle, "sign-in cycle is expired" if cycle.expired?
    end

    def ensure_actor_binding!
      raise InvalidCycle, "sign-in cycle is not bound to an actor" if cycle.principal_id.blank?
      raise ActorMismatch, "actor does not match sign-in cycle" unless cycle.principal_id == actor.id
    end

    def create_token!(metadata)
      token_class = metadata.fetch(:token_class)
      ensure_reference_defaults!(token_class)

      attrs = {
        metadata.fetch(:foreign_key) => actor.id,
      }
      attrs[:dpop_jkt] = dpop_jkt if dpop_jkt.present?

      token_class.create!(attrs)
    end

    def ensure_reference_defaults!(token_class)
      reference_models_for(token_class).each do |model|
        model.ensure_defaults! if model.respond_to?(:ensure_defaults!)
      end
    end

    def reference_models_for(token_class)
      case token_class.name
      when "ClientToken"
        [ClientTokenStatus, ClientTokenKind, ClientTokenBindingMethod, ClientTokenDbscStatus]
      when "VisitorToken"
        [VisitorTokenStatus, VisitorTokenKind, VisitorTokenBindingMethod, VisitorTokenDbscStatus]
      when "OperatorToken"
        [OperatorTokenStatus, OperatorTokenKind, OperatorTokenBindingMethod, OperatorTokenDbscStatus]
      else
        []
      end
    end
  end
end
