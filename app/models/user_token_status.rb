# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_token_statuses
# Database name: mark
#
#  id :bigint           not null, primary key
#

class UserTokenStatus < MarkRecord
  NOTHING = 0
  ACTIVE = 1
  EXPIRED = 2
  has_many :user_tokens, dependent: :restrict_with_error
end
