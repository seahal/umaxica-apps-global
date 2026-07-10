# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_memberships
# Database name: avatar
#
#  id                          :bigint           not null, primary key
#  valid_from                  :datetime         not null
#  valid_to                    :datetime         default(Infinity), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  actor_id                    :bigint           not null
#  avatar_id                   :bigint           not null
#  avatar_membership_status_id :bigint
#  granted_by_actor_id         :bigint
#  role_id                     :bigint           default(0), not null
#
# Indexes
#
#  index_avatar_memberships_on_actor_id                     (actor_id) WHERE (valid_to = 'infinity'::timestamp with time zone)
#  index_avatar_memberships_on_avatar_id_and_actor_id       (avatar_id,actor_id) UNIQUE WHERE (valid_to = 'infinity'::timestamp with time zone)
#  index_avatar_memberships_on_avatar_membership_status_id  (avatar_membership_status_id)
#  index_avatar_memberships_on_role_id                      (role_id)
#
# Foreign Keys
#
#  fk_rails_...  (avatar_id => avatars.id)
#  fk_rails_...  (avatar_membership_status_id => avatar_membership_statuses.id)
#  fk_rails_...  (role_id => avatar_roles.id)
#

require "test_helper"

class AvatarMembershipTest < ActiveSupport::TestCase
  test "validations" do
    membership = AvatarMembership.new

    assert_not membership.valid?
    # valid_from is required but might be auto-set by DB default? No, schema says
    # not null, model validation says presence.
    # But usually creating empty object checks presence.
  end

  test "assigns numeric id" do
    record = AvatarMembership.new(id: 99)

    assert_equal 99, record.id
  end
end
