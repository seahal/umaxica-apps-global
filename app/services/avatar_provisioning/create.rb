# typed: false
# frozen_string_literal: true

module AvatarProvisioning
  class Create < ApplicationService
    Result =
      Data.define(:avatar, :handle, :binding, :assignment, :errors) do
        def success? = errors.empty?
      end

    SUPPORTED_SUBJECT_TYPES = %w(persona agent individual).freeze
    DEFAULT_ASSIGNMENT_ROLE = "owner"

    def initialize(actor:, subject_type:, subject:, avatar_params:, handle_params: {},
                   assignment_role: DEFAULT_ASSIGNMENT_ROLE, organization_public_id: nil)
      super()
      @actor = actor
      @subject_type = subject_type.to_s
      @subject = subject
      @avatar_params = avatar_params.to_h.symbolize_keys
      @handle_params = handle_params.to_h.symbolize_keys
      @assignment_role = assignment_role.to_s
      @organization_public_id = organization_public_id
    end

    def call
      validate_inputs!

      avatar = nil
      handle = nil
      binding = nil
      assignment = nil

      Avatar.transaction do
        ensure_reference_rows!
        handle = create_handle!
        avatar = create_avatar!(handle)
        binding = create_binding!(avatar)
        assignment = avatar.avatar_assignments.create!(user: actor, role: assignment_role)
      end

      Result.new(avatar: avatar, handle: handle, binding: binding, assignment: assignment, errors: [])
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Result.new(avatar: avatar, handle: handle, binding: binding, assignment: assignment, errors: [e])
    end

    private

    attr_reader :actor, :subject_type, :subject, :avatar_params, :handle_params, :assignment_role,
                :organization_public_id

    def validate_inputs!
      raise ArgumentError, "actor is required" unless actor.is_a?(Client)
      raise ArgumentError, "unsupported subject_type: #{subject_type.inspect}" unless
        SUPPORTED_SUBJECT_TYPES.include?(subject_type)
      raise ArgumentError, "subject is required" if subject.blank?
      raise ArgumentError, "assignment_role is required" if assignment_role.blank?
    end

    def ensure_reference_rows!
      HandleStatus.ensure_defaults! if HandleStatus.respond_to?(:ensure_defaults!)
      AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
      AvatarLifecycleState.find_by!(key: "active")
    end

    def create_handle!
      Handle.create!(
        handle: avatar_handle,
        handle_status_id: HandleStatus::ACTIVE,
        cooldown_until: Time.current,
        is_system: false,
      )
    end

    def create_avatar!(handle)
      Avatar.create!(
        moniker: avatar_params[:moniker],
        active_handle: handle,
        capability_id: AvatarCapability::NORMAL,
        lifecycle_state: AvatarLifecycleState.find_by!(key: "active"),
        client_id: legacy_compatibility_client_id,
        owner_organization_id: organization_public_id,
        representing_organization_id: organization_public_id,
        image_data: {},
      )
    end

    def create_binding!(avatar)
      case subject_type
      when "persona"
        AvatarPersonaBinding.create!(avatar: avatar, persona: subject)
      when "agent"
        AvatarAgentBinding.create!(avatar: avatar, agent: subject)
      when "individual"
        AvatarIndividualBinding.create!(avatar: avatar, individual: subject)
      else
        raise ArgumentError, "unsupported subject_type: #{subject_type.inspect}"
      end
    end

    def avatar_handle
      base = handle_params[:handle].presence || avatar_params.fetch(:moniker)
      "#{base.to_s.parameterize.presence || "avatar"}-#{SecureRandom.alphanumeric(8).downcase}"
    end

    # Migration compatibility only. Ownership, authorization, and canonical subject relation
    # come from AvatarAssignment plus the surface binding tables, not avatars.client_id.
    def legacy_compatibility_client_id
      actor.id
    end
  end
end
