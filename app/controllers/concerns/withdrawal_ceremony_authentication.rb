# typed: false
# frozen_string_literal: true

module WithdrawalCeremonyAuthentication
  extend ActiveSupport::Concern
  include WithdrawalCeremonyCookie

  private

  def issue_withdrawal_ceremony!(subject:, purpose: "status")
    ceremony = withdrawal_ceremony_class.issue!(subject: subject, purpose: purpose, request: request)
    write_withdrawal_ceremony_cookie!(ceremony)
    @current_withdrawal_ceremony = ceremony
    @current_withdrawal_subject = subject
    ceremony
  end

  def current_withdrawal_ceremony
    return @current_withdrawal_ceremony if defined?(@current_withdrawal_ceremony)

    public_id, token = read_withdrawal_ceremony_cookie
    @current_withdrawal_ceremony = withdrawal_ceremony_class.authenticate(public_id: public_id, token: token)
  end

  def current_withdrawal_subject
    return @current_withdrawal_subject if defined?(@current_withdrawal_subject)

    @current_withdrawal_subject = current_withdrawal_ceremony&.subject
  end

  def withdrawal_ceremony_required!
    return if current_withdrawal_subject.present?

    clear_withdrawal_ceremony_cookie!
    safe_redirect_to(withdrawal_new_path, fallback: withdrawal_public_fallback_path, status: :see_other)
  end

  def revoke_current_withdrawal_ceremony!
    ceremony = current_withdrawal_ceremony
    ceremony&.revoke! if ceremony&.active?
    clear_withdrawal_ceremony_cookie!
    @current_withdrawal_ceremony = nil
    @current_withdrawal_subject = nil
  end

  def consume_current_withdrawal_ceremony!
    ceremony = current_withdrawal_ceremony
    ceremony&.consume! if ceremony&.active?
    clear_withdrawal_ceremony_cookie!
    @current_withdrawal_ceremony = nil
    @current_withdrawal_subject = nil
  end
end
