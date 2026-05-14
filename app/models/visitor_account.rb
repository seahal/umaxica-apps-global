# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: clients
# Database name: principal
#
#  id               :bigint           not null, primary key
#  lock_version     :integer          default(0), not null
#  moniker          :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  client_status_id :bigint           default(0), not null
#  division_id      :bigint
#  public_id        :string           not null
#  status_id        :bigint           default(0), not null
#  user_id          :bigint
#
# Indexes
#
#  index_clients_on_client_status_id  (client_status_id)
#  index_clients_on_division_id       (division_id)
#  index_clients_on_public_id         (public_id) UNIQUE
#  index_clients_on_status_id         (status_id)
#  index_clients_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_clients_on_client_status_id  (client_status_id => client_statuses.id)
#  fk_clients_on_status_id         (status_id => client_statuses.id)
#  fk_rails_...                    (client_status_id => client_statuses.id)
#  fk_rails_...                    (user_id => users.id) ON DELETE => nullify
#
class VisitorAccount < PrincipalRecord
  self.table_name = "clients"

  belongs_to :client_status,
             class_name: "VisitorAccountStatus",
             inverse_of: :clients
  belongs_to :status,
             class_name: "VisitorAccountStatus",
             inverse_of: :status_clients
  belongs_to :user,
             optional: true,
             inverse_of: :clients

  has_many :client_banners,
           class_name: "VisitorAccountBanner",
           dependent: :destroy,
           inverse_of: :client
end
