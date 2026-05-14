# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_banners
# Database name: operator
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  ends_at    :datetime         default(9999-12-31 23:59:59.000000000 UTC +00:00), not null
#  published  :boolean          default(FALSE), not null
#  starts_at  :datetime         not null
#  title      :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  staff_id   :bigint           not null
#
# Indexes
#
#  index_staff_banners_on_staff_id  (staff_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#
class OperatorBanner < OperatorRecord
  self.table_name = "staff_banners"
  include BannerModel

  belongs_to :staff, class_name: "Operator", optional: false

  def actor
    staff
  end
end
