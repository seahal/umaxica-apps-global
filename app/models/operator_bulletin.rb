# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_bulletins
# Database name: org_principal
#
#  id         :bigint           not null, primary key
#  body       :text
#  read_at    :datetime
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string(21)       not null
#  staff_id   :bigint           not null
#
# Indexes
#
#  index_staff_bulletins_on_public_id  (public_id) UNIQUE
#  index_staff_bulletins_on_staff_id   (staff_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#
class OperatorBulletin < OrgPrincipalRecord
  self.table_name = "staff_bulletins"
  include PublicId

  belongs_to :staff, inverse_of: :staff_bulletins, class_name: "Operator"

  validates :title, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :oldest_first, -> { order(created_at: :asc) }

  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end
end
