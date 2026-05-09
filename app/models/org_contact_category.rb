# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_contact_categories
# Database name: guest
#
#  id :bigint           not null, primary key
#
class OrgContactCategory < GuestRecord
  include ReferenceRecord

  NOTHING = 1
  ORGANIZATION_INQUIRY = 2

  has_many :org_contacts,
           foreign_key: :category_id,
           inverse_of: :org_contact_category,
           dependent: :restrict_with_exception

  validates :id, uniqueness: true
end
