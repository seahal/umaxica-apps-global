# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_token_statuses
# Database name: token
#
#  id :bigint           not null, primary key
#

class StaffTokenStatus < TokenRecord
  include ReferenceRecord

  ACTIVE = 1
  NOTHING = 0
  EXPIRED = 2
  has_many :staff_tokens, dependent: :restrict_with_error
end
