# typed: false
# frozen_string_literal: true

module Acme
  module Selector
    class Authority
      InvalidSelection = Class.new(StandardError)

      def self.prepare(surface:, principal:, session:)
        new(surface: surface, principal: principal, session: session).prepare
      end

      def self.select(surface:, principal:, session:, params:)
        new(surface: surface, principal: principal, session: session).select(params)
      end

      def initialize(surface:, principal:, session:)
        @config = Acme::Selector.config_for(surface)
        @principal = principal
        @session = session
      end

      def prepare
        candidates = selectable_candidates
        return selection_required(candidates) unless candidates.one?

        persist_selection!(candidates.first)
        selected
      end

      def select(params)
        candidate = candidate_for_public_ids(params)
        raise InvalidSelection, "invalid_selection" if candidate.blank?

        persist_selection!(candidate)
        selected
      end

      def selectable_candidates
        accounts.flat_map do |account|
          account.current_memberships.flat_map do |membership|
            next [] unless membership.active?

            collective = membership.collective
            unit = membership.collective_unit
            avatars_for(collective).map do |avatar|
              candidate(account: account, collective: collective, unit: unit, avatar: avatar)
            end
          end
        end
      end

      private

      attr_reader :config, :principal, :session

      def accounts
        config.account_class
          .joins(config.account_identity_association)
          .where(config.identity_class.table_name => { source_record_id: principal.id })
          .order(:created_at, :id)
      end

      def avatars_for(collective)
        return [nil] unless config.requires_avatar

        Avatar
          .joins(:avatar_assignments)
          .where(avatar_assignments: { user_id: principal.id })
          .where(owner_organization_id: collective.public_id)
          .distinct
          .order(:created_at, :id)
      end

      def candidate(account:, collective:, unit:, avatar:)
        {
          account: account,
          collective: collective,
          unit: unit,
          avatar: avatar,
          public: {
            account_public_id: account.public_id,
            organization_public_id: collective.public_id,
            organization_unit_public_id: unit.public_id,
            avatar_public_id: avatar&.public_id,
          },
        }
      end

      def candidate_for_public_ids(params)
        normalized = {
          account_public_id: params[:account_public_id].presence,
          organization_public_id: params[:organization_public_id].presence || params[:collective_public_id].presence,
          organization_unit_public_id: params[:organization_unit_public_id].presence ||
            params[:collective_unit_public_id].presence,
          avatar_public_id: params[:avatar_public_id].presence,
        }

        selectable_candidates.find do |candidate|
          public_ids = candidate.fetch(:public)
          public_ids[:account_public_id] == normalized[:account_public_id] &&
            public_ids[:organization_public_id] == normalized[:organization_public_id] &&
            public_ids[:organization_unit_public_id] == normalized[:organization_unit_public_id] &&
            public_ids[:avatar_public_id].to_s == normalized[:avatar_public_id].to_s
        end
      end

      def persist_selection!(candidate)
        raise InvalidSelection, "session_required" if session.blank?

        public_ids = candidate.fetch(:public)
        attributes = {
          selected_account_public_id: public_ids[:account_public_id],
          selected_collective_public_id: public_ids[:organization_public_id],
          selected_collective_unit_public_id: public_ids[:organization_unit_public_id],
          selected_at: Time.current,
        }
        attributes[:selected_avatar_public_id] = public_ids[:avatar_public_id] if session.respond_to?(:selected_avatar_public_id=)

        connection_owner(session.class).connected_to(role: :writing) { session.update!(attributes) }
      end

      def selected
        { status: "selected", next: "/dashboard" }
      end

      def connection_owner(klass)
        owner = klass
        owner = owner.superclass until owner.connection_class? || owner == ApplicationRecord
        owner
      end

      def selection_required(candidates)
        {
          status: "selection_required",
          accounts: serialize_candidates(candidates),
        }
      end

      def serialize_candidates(candidates)
        candidates.flatten.map do |candidate|
          public_ids = candidate.fetch(:public)
          {
            public_id: public_ids[:account_public_id],
            organization: {
              public_id: public_ids[:organization_public_id],
              unit_public_id: public_ids[:organization_unit_public_id],
            },
            avatar: public_ids[:avatar_public_id].present? ? { public_id: public_ids[:avatar_public_id] } : nil,
          }
        end
      end
    end
  end
end
