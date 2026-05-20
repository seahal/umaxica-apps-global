# typed: false
# == Schema Information
#
# Table name: user_token_kinds
# Database name: app_ticket
#
#  id :bigint           not null, primary key
#
# frozen_string_literal: true

class ClientTokenKind < AppTicketRecord
  self.table_name = "user_token_kinds"
  include ReferenceRecord

  self.primary_key = :id
  self.record_timestamps = false

  BROWSER_WEB = 11
  CLIENT_IOS = 12
  CLIENT_ANDROID = 13

  DEFAULTS = [BROWSER_WEB, CLIENT_IOS, CLIENT_ANDROID].freeze

  has_many :client_tokens, dependent: :restrict_with_error
end
