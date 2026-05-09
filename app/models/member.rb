# typed: false
# == Schema Information
#
# Table name: members
# Database name: principal
#
#  id          :bigint           not null, primary key
#  lapses_at   :datetime         default(Infinity), not null
#  moniker     :string
#  purge_at    :datetime         default(Infinity), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  division_id :bigint
#  public_id   :string           not null
#  status_id   :bigint           default(5), not null
#  user_id     :bigint
#
# Indexes
#
#  index_members_on_division_id  (division_id)
#  index_members_on_public_id    (public_id) UNIQUE
#  index_members_on_purge_at     (purge_at)
#  index_members_on_status_id    (status_id)
#  index_members_on_user_id      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => member_statuses.id)
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#

# frozen_string_literal: true

class Member < PrincipalRecord
  include Retainable
  include ::Account

  attribute :status_id, default: MemberStatus::NOTHING

  belongs_to :user, optional: true, inverse_of: :owned_members
  belongs_to :member_status,
             foreign_key: :status_id,
             inverse_of: :members
  belongs_to :division, optional: true, inverse_of: :members
  has_many :avatars, dependent: :nullify, inverse_of: :member
  has_many :member_avatar_accesses, dependent: :destroy, inverse_of: :member
  has_many :member_avatar_visibilities, dependent: :destroy, inverse_of: :member
  has_many :member_avatar_oversights, dependent: :destroy, inverse_of: :member
  has_many :member_avatar_extractions, dependent: :destroy, inverse_of: :member
  has_many :member_avatar_impersonations, dependent: :destroy, inverse_of: :member
  has_many :member_avatar_suspensions, dependent: :destroy, inverse_of: :member
  has_many :member_avatar_deletions, dependent: :destroy, inverse_of: :member
  has_many :user_member_discoveries,
           class_name: "UserMemberDiscovery",
           dependent: :destroy,
           inverse_of: :member
  has_many :user_member_observations,
           class_name: "UserMemberObservation",
           dependent: :destroy,
           inverse_of: :member
  has_many :user_member_revocations,
           class_name: "UserMemberRevocation",
           dependent: :destroy,
           inverse_of: :member
  has_many :user_member_impersonations,
           class_name: "UserMemberImpersonation",
           dependent: :destroy,
           inverse_of: :member
  has_many :user_member_suspensions,
           class_name: "UserMemberSuspension",
           dependent: :destroy,
           inverse_of: :member
  has_many :user_member_deletions,
           class_name: "UserMemberDeletion",
           dependent: :destroy,
           inverse_of: :member
  has_many :user_members, dependent: :destroy
  has_many :users, through: :user_members
end
