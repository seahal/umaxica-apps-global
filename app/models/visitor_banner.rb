# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_banners
# Database name: com_principal
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  ends_at    :datetime         default(9999-12-31 23:59:59.000000000 UTC +00:00), not null
#  published  :boolean          default(FALSE), not null
#  starts_at  :datetime         not null
#  title      :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  visitor_id :bigint           not null
#
# Indexes
#
#  index_visitor_banners_on_visitor_id  (visitor_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_id => visitors.id)
#
class VisitorBanner < ComPrincipalRecord
  include BannerModel

  belongs_to :visitor, optional: false, inverse_of: :visitor_banners

  def actor
    visitor
  end
end
