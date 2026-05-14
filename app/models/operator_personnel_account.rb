# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_accounts
# Database name: personnel
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  staff_id   :bigint           not null
#
# Indexes
#
#  index_staff_accounts_on_public_id  (public_id) UNIQUE
#  index_staff_accounts_on_staff_id   (staff_id) UNIQUE
#
class OperatorPersonnelAccount < PersonnelRecord
  self.table_name = "staff_accounts"
  include ::PublicId

  belongs_to :staff, inverse_of: :staff_account, class_name: "Operator"

  validates :staff_id, uniqueness: true
end
