# typed: false
# == Schema Information
#
# Table name: user_token_kinds
# Database name: mark
#
#  id :bigint           not null, primary key
#
# frozen_string_literal: true

class UserTokenKind < MarkRecord
  self.primary_key = :id
  self.record_timestamps = false

  BROWSER_WEB = 11
  CLIENT_IOS = 12
  CLIENT_ANDROID = 13

  has_many :user_tokens, dependent: :restrict_with_error
end
