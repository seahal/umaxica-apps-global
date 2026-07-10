# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_accounts
# Database name: com_zenith
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  visitor_id :bigint           not null
#
# Indexes
#
#  index_visitor_accounts_on_public_id   (public_id) UNIQUE
#  index_visitor_accounts_on_visitor_id  (visitor_id) UNIQUE
#
class VisitorAccount < ComRpRecord
  include ::PublicId

  belongs_to :visitor, inverse_of: :rp_account

  validates :visitor_id, uniqueness: true
end
