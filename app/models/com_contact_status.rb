# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_contact_statuses
# Database name: guest
#
#  id :bigint           not null, primary key
#
class ComContactStatus < GuestRecord
  include ReferenceRecord

  NOTHING = 1
  COMPLETED = 5
  SET_UP = 7
  NULL_COM_STATUS = 8
  COMPLETED_CONTACT_ACTION = 10

  has_many :com_contacts,
           foreign_key: :status_id,
           inverse_of: :com_contact_status,
           dependent: :restrict_with_error
end
