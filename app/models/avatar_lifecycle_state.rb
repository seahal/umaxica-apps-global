# typed: false
# frozen_string_literal: true

# Current Avatar lifecycle state authority.
class AvatarLifecycleState < AvatarRecord
  validates :key, presence: true, uniqueness: true
  validates :title, presence: true
  validates :sort_order, presence: true, uniqueness: true
end
