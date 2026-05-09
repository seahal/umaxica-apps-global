# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_visibilities
# Database name: guest
#
#  id :bigint           not null, primary key
#

class CustomerVisibility < GuestRecord
  include ReferenceRecord

  NOBODY = 0
  CUSTOMER = 1
  STAFF = 2
  BOTH = 3
  DEFAULTS = [NOBODY, CUSTOMER, STAFF, BOTH].freeze

  has_many :customers,
           foreign_key: :visibility_id,
           dependent: :restrict_with_error,
           inverse_of: :visibility
end
