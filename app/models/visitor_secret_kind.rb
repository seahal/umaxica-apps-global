# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_secret_kinds
# Database name: guest
#
#  id :bigint           not null, primary key
#
class VisitorSecretKind < GuestRecord
  LOGIN = 1
  RECOVERY = 3
  API = 4
  PERMANENT = LOGIN
  ONE_TIME = RECOVERY
  ALLOWED_FOR_SECRET_SIGN_IN = [PERMANENT, ONE_TIME].freeze
  ALL = [LOGIN, RECOVERY, API].freeze

  validates :id, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :id, uniqueness: true

  has_many :visitor_secrets, inverse_of: :visitor_secret_kind, dependent: :restrict_with_exception
end
