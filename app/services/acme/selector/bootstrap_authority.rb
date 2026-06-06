# typed: false
# frozen_string_literal: true

module Acme
  module Selector
    class BootstrapAuthority
      ISSUER = "acme-selector-bootstrap"
      AUDIENCE = "acme"

      def self.call(surface:, principal:)
        new(surface: surface, principal: principal).call
      end

      def initialize(surface:, principal:)
        @config = Acme::Selector.config_for(surface)
        @principal = principal
      end

      def call
        raise ArgumentError, "principal is required" unless principal.is_a?(config.principal_class)

        with_writing_connections do
          config.principal_class.lock.find(principal.id)
          ensure_reference_rows!
          rp_account = ensure_rp_account!
          identity = ensure_identity!
          account = ensure_account!(identity)
          collective = ensure_collective_for(account)
          unit = ensure_root_unit!(collective)
          ensure_membership!(account: account, collective: collective, unit: unit)
          ensure_avatar!(account: account, collective: collective) if config.requires_avatar

          BootstrapResult.new(
            rp_account: rp_account, identity: identity, account: account,
            collective: collective, unit: unit,
          )
        end
      end

      private

      attr_reader :config, :principal

      BootstrapResult = Data.define(:rp_account, :identity, :account, :collective, :unit)

      def with_writing_connections(&block)
        connection_owners.reduce(block) do |inner, owner|
          -> { owner.connected_to(role: :writing, &inner) }
        end.call
      end

      def connection_owners
        [
          connection_owner(config.principal_class),
          connection_owner(config.rp_account_class),
          connection_owner(config.token_class),
          (connection_owner(Avatar) if config.requires_avatar),
        ].compact.uniq
      end

      def connection_owner(klass)
        owner = klass
        owner = owner.superclass until owner.connection_class? || owner == ApplicationRecord
        owner
      end

      def ensure_reference_rows!
        [
          config.identity_state_class,
          config.membership_kind_class,
          config.membership_state_class,
          (AvatarCapability if config.requires_avatar),
          (HandleStatus if config.requires_avatar),
        ].compact.each { |klass| klass.ensure_defaults! if klass.respond_to?(:ensure_defaults!) }

        AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL) if config.requires_avatar
      end

      def ensure_rp_account!
        create_unique(config.rp_account_class, { config.rp_account_foreign_key => principal.id })
      end

      def ensure_identity!
        attributes = {
          issuer: ISSUER,
          subject: principal.public_id,
          audience: AUDIENCE,
          source_record_id: principal.id,
          status_id: config.identity_state_class::ACTIVE,
        }
        create_unique(config.identity_class, attributes, lookup: { source_record_id: principal.id })
      end

      def ensure_account!(identity)
        association_key = :"#{config.account_identity_association}_id"
        create_unique(
          config.account_class,
          { association_key => identity.id, :moniker => config.account_moniker },
          lookup: { association_key => identity.id },
        )
      end

      def ensure_collective_for(account)
        membership = account.current_memberships.first
        return membership.collective if membership.present?

        config.collective_class.create!(name: config.collective_name)
      end

      def ensure_root_unit!(collective)
        collective.root_units.order(:created_at, :id).first ||
          config.unit_class.create!(config.unit_collective_association => collective, :name => "Default")
      end

      def ensure_membership!(account:, collective:, unit:)
        existing = account.memberships.current.primary_first.first
        return existing if existing.present?

        config.membership_class.create!(
          config.membership_account_association => account,
          config.membership_collective_association => collective,
          config.membership_unit_association => unit,
          :membership_kind_id => config.membership_kind_class::OWNER,
          :membership_state_id => config.membership_state_class::ACTIVE,
          :primary => true,
          :metadata => {},
          :starts_at => Time.current,
        )
      rescue ActiveRecord::RecordNotUnique
        account.memberships.current.primary_first.first || raise
      end

      def ensure_avatar!(account:, collective:)
        return if AvatarAssignment.exists?(user_id: principal.id, role: "owner")

        handle = create_unique(
          Handle,
          {
            handle: default_handle,
            handle_status_id: HandleStatus::ACTIVE,
            cooldown_until: Time.current,
            is_system: false,
          },
          lookup: { handle: default_handle, is_system: false },
        )
        Avatar.create_with_owner(
          {
            moniker: "Default Avatar",
            active_handle: handle,
            capability_id: AvatarCapability::NORMAL,
            client_id: principal.id,
            owner_organization_id: collective.public_id,
            representing_organization_id: collective.public_id,
            image_data: {},
          },
          principal,
        )
      rescue ActiveRecord::RecordNotUnique
        AvatarAssignment.where(user_id: principal.id, role: "owner").first&.avatar || raise
      end

      def default_handle
        "user-#{principal.public_id.downcase}"
      end

      def create_unique(klass, attributes, lookup: attributes)
        klass.find_or_create_by!(lookup) do |record|
          attributes.each { |key, value| record.public_send("#{key}=", value) }
        end
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        record = klass.find_by(lookup)
        return record if record.present?

        raise
      end
    end
  end
end
