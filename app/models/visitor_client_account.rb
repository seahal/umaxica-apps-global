# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_accounts
# Database name: visitor
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  visitor_id :bigint           not null
#
# Indexes
#
#  index_client_accounts_on_public_id   (public_id) UNIQUE
#  index_client_accounts_on_visitor_id  (visitor_id) UNIQUE
#
class VisitorClientAccount < VisitorRecord
  self.table_name = "client_accounts"

  include ::PublicId

  belongs_to :visitor, inverse_of: :client_account

  validates :visitor_id, uniqueness: true
end
