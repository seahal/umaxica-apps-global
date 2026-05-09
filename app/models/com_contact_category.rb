# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_contact_categories
# Database name: guest
#
#  id :bigint           not null, primary key
#
class ComContactCategory < GuestRecord
  include ReferenceRecord

  NOTHING = 1
  SECURITY_ISSUE = 2

  has_many :com_contacts,
           foreign_key: :category_id,
           inverse_of: :com_contact_category,
           dependent: :restrict_with_exception
end
