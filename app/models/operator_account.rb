# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_accounts
# Database name: org_zenith
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  staff_id   :bigint           not null
#
# Indexes
#
#  index_operator_accounts_on_public_id  (public_id) UNIQUE
#  index_operator_accounts_on_staff_id   (staff_id) UNIQUE
#
class OperatorAccount < OrgRpRecord
  include ::PublicId

  belongs_to :staff, inverse_of: :rp_account, class_name: "Operator"

  validates :staff_id, uniqueness: true
end
