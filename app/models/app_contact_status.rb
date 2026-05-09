# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_contact_statuses
# Database name: guest
#
#  id :bigint           not null, primary key
#
class AppContactStatus < GuestRecord
  include ReferenceRecord

  NOTHING = 1
  CHECKED_EMAIL_ADDRESS = 2
  EMAIL_PENDING = 3
  PHONE_VERIFIED = 4
  COMPLETED = 5
  EMAIL_VERIFIED = 6
  SET_UP = 7
  CHECKED_TELEPHONE_NUMBER = 9
  COMPLETED_CONTACT_ACTION = 10

  has_many :app_contacts,
           foreign_key: :status_id,
           inverse_of: :app_contact_status,
           dependent: :restrict_with_error
end
