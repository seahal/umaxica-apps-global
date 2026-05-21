# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_social_apples
# Database name: app_principal
#
#  id                    :bigint           not null, primary key
#  last_authenticated_at :datetime
#  provider              :string           default("apple"), not null
#  refresh_token         :string           default(""), not null
#  token                 :string           default(""), not null
#  token_expires_at      :integer          not null
#  uid                   :string           default(""), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  status_id             :bigint           default(1), not null
#  user_id               :bigint           not null
#
# Indexes
#
#  index_client_social_apples_on_status_id              (status_id)
#  index_client_social_apples_on_token_expires_at       (token_expires_at)
#  index_client_social_apples_on_uid_and_provider       (uid,provider) UNIQUE
#  index_user_identity_social_apples_on_user_id_unique  (user_id) UNIQUE WHERE (user_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => client_social_apple_statuses.id)
#  fk_rails_...  (user_id => clients.id)
#

class ClientSocialApple < AppPrincipalRecord
  include SocialIdentifiable

  alias_attribute :expires_at, :token_expires_at
  attribute :status_id, default: ClientSocialAppleStatus::ACTIVE

  belongs_to :user, class_name: "Client", inverse_of: :user_social_apple
  belongs_to :user_social_apple_status, class_name: "ClientSocialAppleStatus",
                                        inverse_of: :client_social_apples,
                                        foreign_key: :status_id

  validates :token, presence: true
  validates :user_id, uniqueness: { conditions: -> { where.not(user_id: nil) } }
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :token_expires_at, presence: true
  validates :status_id, numericality: { only_integer: true }

  def self.status_column
    :status_id
  end

  def self.status_class
    ClientSocialAppleStatus
  end
end
