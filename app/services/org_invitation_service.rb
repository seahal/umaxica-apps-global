# typed: false
# frozen_string_literal: true

class OrgInvitationService
  Result =
    Data.define(:success, :invitation, :code, :error) do
      def success? = !!success
    end

  def self.create(organization_id:, email:, invited_by:, role_id: 0)
    new(organization_id: organization_id, email: email, invited_by: invited_by, role_id: role_id).create
  end

  def self.validate(code:, email: nil)
    new.validate(code: code, email: email)
  end

  def self.consume(code:, email: nil)
    new.consume(code: code, email: email)
  end

  def initialize(organization_id: nil, email: nil, invited_by: nil, role_id: 0)
    @organization_id = organization_id
    @email = email
    @invited_by = invited_by
    @role_id = role_id
  end

  def create
    invitation = OrganizationInvitation.new(
      organization_id: @organization_id,
      email: @email.to_s.downcase.strip,
      invited_by_id: @invited_by.id,
      role_id: @role_id,
    )

    if invitation.save
      Result.new(success: true, invitation: invitation, code: invitation.code, error: nil)
    else
      Result.new(success: false, invitation: nil, code: nil, error: invitation.errors.full_messages.join(", "))
    end
  end

  def validate(code:, email: nil)
    invitation = OrganizationInvitation.find_valid(code, email: email)

    if invitation
      Result.new(success: true, invitation: invitation, code: code, error: nil)
    else
      Result.new(success: false, invitation: nil, code: code, error: "Invalid or expired invitation code")
    end
  end

  def consume(code:, email: nil)
    invitation = OrganizationInvitation.find_valid(code, email: email)

    unless invitation
      return Result.new(success: false, invitation: nil, code: code, error: "Invalid or expired invitation code")
    end

    if invitation.consume!
      Result.new(success: true, invitation: invitation, code: code, error: nil)
    else
      Result.new(success: false, invitation: invitation, code: code, error: "Failed to consume invitation")
    end
  end
end
