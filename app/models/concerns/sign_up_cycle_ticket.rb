# typed: false
# frozen_string_literal: true

module SignUpCycleTicket
  extend ActiveSupport::Concern

  CONTACT_TYPES = %w(email telephone social_identity).freeze
  SECRET_REQUIREMENT_KEY_PATTERNS = [
    /otp/i,
    /pass_?code/i,
    /secret/i,
    /token/i,
    /cookie/i,
    /authorization/i,
    /challenge/i,
  ].freeze

  included do
    before_validation :assign_cleanup_token
    before_validation :normalize_completed_requirements

    validates :entry_method, presence: true, inclusion: { in: ->(record) { record.class::ENTRY_METHODS } }
    validates :pending_contact_type, inclusion: { in: CONTACT_TYPES }, allow_nil: true
    validates :cleanup_token, presence: true
    validates :completed_requirements, exclusion: { in: [nil] }
    validate :completed_requirements_is_object
    validate :return_to_is_safe_internal_path
    validate :completed_requirements_exclude_secret_material
  end

  class_methods do
    def social_entry_methods
      defined?(self::SOCIAL_ENTRY_METHODS) ? self::SOCIAL_ENTRY_METHODS : []
    end
  end

  def social_entry_method?
    self.class.social_entry_methods.include?(entry_method)
  end

  def requirement_cleared?(requirement)
    requirement_state = completed_requirements.fetch(requirement.to_s, {})

    requirement_state.is_a?(Hash) && requirement_state["cleared"] == true
  end

  def advance_sign_up_to_checkpoint!(now: Time.current)
    transition_sign_up_to!(
      "CHECKPOINT_PENDING",
      step: "checkpoint",
      allowed_from: %w(CONTACT_VERIFIED GUARDRAIL_PENDING),
      now: now,
    )
  end

  def complete_sign_up!(step: "completed", now: Time.current)
    changes = { step: step }
    changes[:completed_at] = now if has_attribute?(:completed_at)

    transition_cycle_to!(
      status_id_for("COMPLETED"),
      allowed_from: status_ids_for("SIGN_IN_HANDOFF_PENDING"),
      changes: changes,
      now: now,
    )
  end

  private

  def assign_cleanup_token
    self.cleanup_token = SecureRandom.urlsafe_base64(24) if cleanup_token.blank?
  end

  def normalize_completed_requirements
    self.completed_requirements = {} if completed_requirements.blank?
  end

  def return_to_is_safe_internal_path
    return if return_to.blank?
    return if safe_internal_return_to?(return_to)

    errors.add(:return_to, "must be a safe internal path")
  end

  def completed_requirements_exclude_secret_material
    return unless completed_requirements.is_a?(Hash)

    flattened_keys = flatten_requirement_keys(completed_requirements, include_current_level: false)
    return if flattened_keys.none? { |key| secret_requirement_key?(key) }

    errors.add(:completed_requirements, "must not contain secret material")
  end

  def completed_requirements_is_object
    return if completed_requirements.is_a?(Hash)

    errors.add(:completed_requirements, "must be an object")
  end

  def flatten_requirement_keys(value, include_current_level: true)
    case value
    when Hash
      value.flat_map do |key, nested|
        nested_keys = flatten_requirement_keys(nested)
        include_current_level ? [key.to_s] + nested_keys : nested_keys
      end
    when Array
      value.flat_map { |nested| flatten_requirement_keys(nested) }
    else
      []
    end
  end

  def safe_internal_return_to?(value)
    uri = URI.parse(value.to_s)
    return false if uri.scheme.present? || uri.host.present?

    path = uri.path.to_s
    path.start_with?("/") && !path.start_with?("//")
  rescue URI::InvalidURIError
    false
  end

  def secret_requirement_key?(key)
    SECRET_REQUIREMENT_KEY_PATTERNS.any? { |pattern| pattern.match?(key) }
  end
end
