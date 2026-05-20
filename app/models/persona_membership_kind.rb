# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: persona_membership_kinds
# Database name: app_zenith
#
#  id :bigint           not null, primary key
#
class PersonaMembershipKind < AppRpRecord
  include ReferenceRecord

  NOTHING = 0
  OWNER = 1
  MEMBER = 2
  GUEST = 3
  DEFAULTS = [NOTHING, OWNER, MEMBER, GUEST].freeze

  has_many :persona_memberships,
           foreign_key: :membership_kind_id,
           dependent: :restrict_with_error,
           inverse_of: :membership_kind
end
