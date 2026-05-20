# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_token_binding_methods
# Database name: app_ticket
#
#  id :bigint           not null, primary key
#
class ClientTokenBindingMethod < AppTicketRecord
  self.table_name = "user_token_binding_methods"
  include ReferenceRecord

  NOTHING = 0
  DBSC = 1
  LEGACY = 2
  DEFAULTS = [NOTHING, DBSC, LEGACY].freeze

  has_many :client_tokens,
           foreign_key: :user_token_binding_method_id,
           dependent: :restrict_with_error,
           inverse_of: :user_token_binding_method

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
