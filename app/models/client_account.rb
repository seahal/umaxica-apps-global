# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_accounts
# Database name: app_zenith
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_client_accounts_on_public_id  (public_id) UNIQUE
#  index_client_accounts_on_user_id    (user_id) UNIQUE
#
class ClientAccount < AppRpRecord
  include ::PublicId

  belongs_to :user, class_name: "Client", inverse_of: :rp_account

  validates :user_id, uniqueness: true
end
