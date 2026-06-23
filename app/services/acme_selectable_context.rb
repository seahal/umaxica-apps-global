# typed: false
# frozen_string_literal: true

# Shared selectable-context resolution for the Acme surfaces.
#
# Both the login-time selector (AcmeSelectorAuthority) and the post-login switcher
# (AcmeSwitcherAuthority) need the same notion of "which account / organization / avatar
# combinations is this principal actually allowed to act as", and the same atomic
# persistence of a chosen combination onto the session token. This module is the single
# source of truth for that candidate resolution and persistence so the two authorities can
# never drift apart on what counts as a valid context.
#
# Includers must expose private readers `config` (an AcmeSelectorSurfaceConfig), `principal`
# (the authenticated subject), and `session` (the session token, may be nil for read-only
# use).
module AcmeSelectableContext
  # Raised when a chosen context cannot be persisted (e.g. no session token to write to).
  InvalidSelection = Class.new(StandardError)

  # Every (account, collective, unit, avatar) combination the principal may act as. For
  # surfaces that do not require an avatar, the avatar slot is nil. Membership must be active
  # and, when an avatar is required, the avatar must be assigned to the principal and owned by
  # the membership's collective -- this is the authoritative ownership/membership gate.
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

  # The single candidate matching the supplied public ids, or nil when the combination is not
  # a real candidate for this principal (cross-user, inconsistent, or avatar mismatch).
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

  # Atomically write the chosen candidate's public ids onto the session token. Validation is
  # the caller's responsibility (candidate must already be confirmed); this only persists.
  def persist_selection!(candidate)
    raise InvalidSelection, "session_required" if session.blank?

    public_ids = candidate.fetch(:public)
    connection_owner(session.class).connected_to(role: :writing) do
      session.with_lock do
        raise InvalidSelection, "invalid_selection" unless candidate_still_authorized?(public_ids)

        attributes = {
          selected_account_public_id: public_ids[:account_public_id],
          selected_collective_public_id: public_ids[:organization_public_id],
          selected_collective_unit_public_id: public_ids[:organization_unit_public_id],
          selected_at: Time.current,
        }
        attributes[:selected_avatar_public_id] =
          public_ids[:avatar_public_id] if session.respond_to?(:selected_avatar_public_id=)

        session.update!(attributes)
      end
    end
  end

  # Flattened, view-friendly serialization of candidates for JSON responses.
  def serialize_candidates(candidates)
    candidates.flatten!
    candidates.map do |candidate|
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

  private

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

  def candidate_still_authorized?(public_ids)
    account = nil
    connection_owner(config.account_class).connected_to(role: :writing) do
      account = config.account_class.lock.find_by(public_id: public_ids[:account_public_id])
    end
    return false unless account

    membership = nil
    connection_owner(config.membership_class).connected_to(role: :writing) do
      membership =
        account.current_memberships.lock.find do |candidate_membership|
          candidate_membership.active? &&
            candidate_membership.collective.public_id == public_ids[:organization_public_id] &&
            candidate_membership.collective_unit.public_id == public_ids[:organization_unit_public_id]
        end
    end
    return false unless membership
    return true unless config.requires_avatar

    connection_owner(Avatar).connected_to(role: :writing) do
      Avatar
        .joins(:avatar_assignments)
        .lock
        .where(public_id: public_ids[:avatar_public_id])
        .where(owner_organization_id: public_ids[:organization_public_id])
        .exists?(avatar_assignments: { user_id: principal.id })
    end
  end

  def connection_owner(klass)
    owner = klass
    owner = owner.superclass until owner.connection_class? || owner == ApplicationRecord
    owner
  end
end
