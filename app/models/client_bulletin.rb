# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_bulletins
# Database name: app_principal
#
#  id         :bigint           not null, primary key
#  body       :text
#  read_at    :datetime
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string(21)       not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_client_bulletins_on_public_id  (public_id) UNIQUE
#  index_client_bulletins_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#
class ClientBulletin < AppPrincipalRecord
  include PublicId

  belongs_to :user, class_name: "Client", inverse_of: :client_bulletins

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
