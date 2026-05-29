# typed: false
# frozen_string_literal: true

module Oidc
  module RpIdentityProvisioning
    extend ActiveSupport::Concern

    included do
      class_attribute :oidc_rp_actor_class_name, instance_accessor: false
      class_attribute :oidc_rp_identity_class_name, instance_accessor: false
      class_attribute :oidc_rp_bridge_class_name, instance_accessor: false
    end

    class_methods do
      def provisions_oidc_rp_identity(actor_class:, identity_class:, bridge_class: nil)
        self.oidc_rp_actor_class_name = actor_class.to_s
        self.oidc_rp_identity_class_name = identity_class.to_s
        self.oidc_rp_bridge_class_name = bridge_class&.to_s
      end
    end

    private

    def provision_rp_account_from_id_token!(payload)
      claims = rp_identity_claims(payload)
      actor = actor_from_existing_identity(claims) || actor_from_subject_claim(claims)

      ensure_rp_identity_for(actor, claims)
      ensure_rp_bridge_for(actor)

      actor
    end

    def rp_identity_claims(payload)
      {
        issuer: payload.fetch("iss").to_s,
        subject: payload.fetch("sub").to_s,
        audience: payload.fetch("aud").to_s,
      }
    end

    def actor_from_existing_identity(claims)
      identity = record_context_for(rp_identity_class).connected_to(role: :reading) do
        rp_identity_class.find_by(claims)
      end
      return unless identity

      find_rp_actor(identity.source_record_id)
    end

    def actor_from_subject_claim(claims)
      find_rp_actor(claims.fetch(:subject))
    end

    def ensure_rp_identity_for(actor, claims)
      record_context_for(rp_identity_class).connected_to(role: :writing) do
        existing = rp_identity_class.find_by(source_record_id: actor.id)
        return existing if existing

        rp_identity_class.create!(
          **claims,
          source_record_id: actor.id,
          status_id: rp_identity_active_status_id,
        )
      end
    rescue ActiveRecord::RecordNotUnique
      record_context_for(rp_identity_class).connected_to(role: :writing) do
        rp_identity_class.find_by!(source_record_id: actor.id)
      end
    end

    def ensure_rp_bridge_for(actor)
      bridge_class = rp_bridge_class
      return unless bridge_class

      record_context_for(bridge_class).connected_to(role: :writing) do
        bridge_class.find_or_create_by!(bridge_class.core_actor_foreign_key => actor.id)
      end
    end

    def rp_actor_class
      self.class.oidc_rp_actor_class_name.constantize
    end

    def rp_identity_class
      self.class.oidc_rp_identity_class_name.constantize
    end

    def rp_bridge_class
      self.class.oidc_rp_bridge_class_name&.constantize
    end

    def rp_identity_active_status_id
      identity_state_class = rp_identity_class.reflect_on_association(:identity_state)&.klass
      return identity_state_class::ACTIVE if identity_state_class&.const_defined?(:ACTIVE, false)

      1
    end

    def find_rp_actor(id)
      record_context_for(rp_actor_class).connected_to(role: :reading) do
        rp_actor_class.find(id)
      end
    end

    def record_context_for(model_class)
      model_class.ancestors.find do |ancestor|
        ancestor.is_a?(Class) &&
          ancestor < ApplicationRecord &&
          ancestor.respond_to?(:abstract_class?) &&
          ancestor.abstract_class? &&
          ancestor != ApplicationRecord
      end || ApplicationRecord
    end
  end
end
