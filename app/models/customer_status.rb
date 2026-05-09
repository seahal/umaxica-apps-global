# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_statuses
# Database name: guest
#
#  id :bigint           not null, primary key
#

class CustomerStatus < GuestRecord
  include ReferenceRecord

  ACTIVE = 1
  NOTHING = 2
  RESERVED = 3
  DEFAULTS = [ACTIVE, NOTHING, RESERVED].freeze

  has_many :customers,
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :customer_status
end
