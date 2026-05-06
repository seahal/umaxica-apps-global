# typed: false
# frozen_string_literal: true

# Base policy class for authorization using Action Policy
# Provides common authorization patterns for both User and Staff actors
class ApplicationPolicy < ActionPolicy::Base
  # By default, Action Policy uses 'user' for the actor.
  # We allow it to be nil for unauthenticated paths.
  authorize :user, optional: true

  # We alias it to 'actor' to match our internal naming.
  alias_rule :edit?, to: :update?
  alias_rule :new?, to: :create?

  def edit? = update?

  def new? = create?

  # Default permissions - deny all by default (allowlist approach)
  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def update?
    false
  end

  def destroy?
    false
  end

  protected

  # Use 'user' as the actor (provided by ActionPolicy)
  def actor
    user
  end

  # Get the organization from the record if it has one
  # @return [Object, nil]
  def organization
    @organization ||=
      if record.respond_to?(:organization)
        record.organization
      elsif record.respond_to?(:organization_id)
        record.organization_id
      end
  end

  # Extract JWT scopes from Current.token (set by authentication)
  # @return [Array<String>]
  def jwt_scopes
    return [] if Current.token.blank?

    Auth::TokenClaims.scopes(Current.token)
  end

  # Check if the actor has a specific scope
  # @param scope [String] the scope to check (e.g., "read:self", "write:org")
  # @return [Boolean]
  def has_scope?(scope)
    jwt_scopes.include?(scope.to_s)
  end

  # Check if the actor has permission for the current domain
  # @param allowed_domains [Array<String>] list of allowed domain prefixes (e.g., ["app", "org"])
  # @return [Boolean]
  def domain_permitted?(*allowed_domains)
    return true if allowed_domains.blank?

    domain = extract_domain_from_audience
    return true if domain.blank?

    allowed_domains.map(&:to_s).include?(domain.to_s)
  end

  # Extract domain from audience claim in Current.token
  def extract_domain_from_audience
    return nil if Current.token.blank?

    audiences = Array(Current.token["aud"])
    return nil if audiences.empty?

    audiences.first.to_s.split(".").first
  end

  # Get JWT subject (actor ID) from Current.token
  def jwt_subject
    return nil if Current.token.blank?

    Auth::TokenClaims.subject(Current.token)
  end

  # Check if current token is for specific domain
  def domain_app?
    extract_domain_from_audience == "app"
  end

  def domain_org?
    extract_domain_from_audience == "org"
  end

  def domain_com?
    extract_domain_from_audience == "com"
  end

  # Check if actor owns the record
  # @return [Boolean]
  def owner?
    return false unless actor
    return jwt_subject.to_s == actor.id.to_s if record.blank?

    if actor.is_a?(User) && record.respond_to?(:user_id)
      record.user_id == actor.id
    elsif actor.is_a?(Staff) && record.respond_to?(:staff_id)
      record.staff_id == actor.id
    else
      false
    end
  end

  # Role-based checks
  def operator?
    actor&.has_role?("operator", organization: organization)
  end

  def manager?
    actor&.has_role?("manager", organization: organization)
  end

  def editor?
    actor&.has_role?("editor", organization: organization)
  end

  def contributor?
    actor&.has_role?("contributor", organization: organization)
  end

  def viewer?
    actor&.has_role?("viewer", organization: organization)
  end

  # Combined role checks
  def operator_or_manager?
    actor&.operator_or_manager?(organization: organization)
  end

  def can_edit?
    actor&.can_edit?(organization: organization)
  end

  def can_view?
    actor&.can_view?(organization: organization)
  end

  def can_contribute?
    actor&.can_contribute?(organization: organization)
  end
end
