# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_banners
# Database name: app_principal
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  ends_at    :datetime         default(9999-12-31 23:59:59.000000000 UTC +00:00), not null
#  published  :boolean          default(FALSE), not null
#  starts_at  :datetime         not null
#  title      :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_user_banners_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ClientBanner < AppPrincipalRecord
  self.table_name = "user_banners"
  include BannerModel

  belongs_to :user, class_name: "Client", optional: false

  def actor
    user
  end
end
