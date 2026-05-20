# typed: false
# == Schema Information
#
# Table name: user_members
# Database name: app_principal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  member_id  :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_user_members_on_member_id              (member_id)
#  index_user_members_on_user_id_and_member_id  (user_id,member_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (member_id => members.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#

# frozen_string_literal: true

class ClientMember < AppPrincipalRecord
  self.table_name = "user_members"
  belongs_to :user, class_name: "Client"
  belongs_to :member

  validates :member_id, uniqueness: { scope: :user_id }
end
