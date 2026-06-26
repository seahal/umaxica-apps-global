# typed: false
# frozen_string_literal: true

class OrgRegistrationPolicy
  class InvitationRequiredError < StandardError; end

  class InvalidInvitationError < StandardError; end

  class InvitationExpiredError < StandardError; end

  class InvitationConsumedError < StandardError; end

  def self.allowed?(invitation_code:, email: nil)
    new(invitation_code: invitation_code, email: email).allowed?
  end

  def self.validate!(invitation_code:, email: nil)
    new(invitation_code: invitation_code, email: email).validate!
  end

  def initialize(invitation_code:, email: nil)
    @invitation_code = invitation_code.to_s.downcase.strip
    @email = email.to_s.downcase.strip.presence
  end

  def allowed?
    return false if @invitation_code.blank?

    result = OrgInvitationService.validate(code: @invitation_code, email: @email)
    result.success?
  end

  def validate!
    raise InvitationRequiredError, "Invitation code is required" if @invitation_code.blank?

    result = OrgInvitationService.validate(code: @invitation_code, email: @email)

    unless result.success?
      invitation = OrganizationInvitation.find_by(code: @invitation_code)

      if invitation&.consumed?
        raise InvitationConsumedError, "Invitation has already been used"
      elsif invitation&.expired?
        raise InvitationExpiredError, "Invitation has expired"
      else
        raise InvalidInvitationError, "Invalid invitation code"
      end
    end

    result.invitation
  end

  def consume!
    invitation = validate!
    result = OrgInvitationService.consume(code: @invitation_code, email: @email)

    unless result.success?
      raise InvalidInvitationError, "Failed to process invitation"
    end

    invitation
  end
end
