# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_monikers
# Database name: avatar
#
#  id                       :bigint           not null, primary key
#  moniker                  :string           not null
#  valid_from               :datetime         not null
#  valid_to                 :datetime         default(Infinity), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  avatar_id                :bigint           not null
#  avatar_moniker_status_id :bigint
#  set_by_actor_id          :bigint
#
# Indexes
#
#  index_avatar_monikers_on_avatar_id                 (avatar_id) UNIQUE WHERE (valid_to = 'infinity'::timestamp with time zone)
#  index_avatar_monikers_on_avatar_id_and_valid_from  (avatar_id,valid_from DESC)
#  index_avatar_monikers_on_avatar_moniker_status_id  (avatar_moniker_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (avatar_id => avatars.id)
#  fk_rails_...  (avatar_moniker_status_id => avatar_moniker_statuses.id)
#

class AvatarMoniker < AvatarRecord
  belongs_to :avatar
  belongs_to :avatar_moniker_status

  validates :avatar_id,
            uniqueness: { conditions: -> { where("valid_to = 'infinity'::timestamp with time zone") } }
  validates :moniker, presence: true
  validates :valid_from, presence: true
  validates :id, length: { maximum: 255 }
end
