# typed: false
# frozen_string_literal: true

module AuthenticationOperator
  extend ActiveSupport::Concern

  include AuthenticationBase

  ACCESS_COOKIE_KEY = AuthenticationBase::ACCESS_COOKIE_KEY
  REFRESH_COOKIE_KEY = AuthenticationBase::REFRESH_COOKIE_KEY
  ACCESS_TOKEN_TTL = AuthenticationBase::ACCESS_TOKEN_TTL
  REFRESH_TOKEN_TTL = AuthenticationBase::REFRESH_TOKEN_TTL
  AUDIT_EVENTS = AuthenticationBase::AUDIT_EVENTS

  def audit_operator_login_failed(operator)
    record_audit(AUDIT_EVENTS[:login_failed], resource: operator, actor: nil) if operator
  end

  def current_operator = current_resource

  def authenticate_operator! = authenticate!

  def logged_in_operator? = logged_in?

  def active_operator?
    current_operator.present? && current_operator.active?
  end

  def am_i_user?
    false
  end

  def am_i_operator?
    true
  end

  def am_i_owner?
    false
  end

  private

  def resource_class
    ::Operator
  end

  def token_class
    OperatorToken
  end

  def audit_class
    ::OperatorChronicle
  end

  def resource_type
    "operator"
  end

  def resource_foreign_key
    :staff_id
  end
end
