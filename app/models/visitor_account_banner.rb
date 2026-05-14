# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_banners
# Database name: principal
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  ends_at    :datetime         default(9999-12-31 23:59:59.000000000 UTC +00:00), not null
#  published  :boolean          default(FALSE), not null
#  starts_at  :datetime         not null
#  title      :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  client_id  :bigint           not null
#
# Indexes
#
#  index_client_banners_on_client_id  (client_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => clients.id)
#
class VisitorAccountBanner < PrincipalRecord
  self.table_name = "client_banners"

  include BannerModel

  belongs_to :client, class_name: "VisitorAccount", optional: false

  def actor
    client
  end
end
