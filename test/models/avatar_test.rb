# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatars
# Database name: avatar
#
#  id                           :bigint           not null, primary key
#  discarded_at                 :datetime         default(Infinity), not null
#  image_data                   :jsonb            not null
#  lock_version                 :integer          default(0), not null
#  moniker                      :string           not null
#  purged_at                    :datetime         default(Infinity), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  active_handle_id             :bigint           not null
#  avatar_status_id             :string
#  capability_id                :bigint           default(0), not null
#  client_id                    :bigint
#  owner_organization_id        :string
#  public_id                    :string           not null
#  representing_organization_id :string
#
# Indexes
#
#  index_avatars_on_active_handle_id              (active_handle_id)
#  index_avatars_on_capability_id                 (capability_id)
#  index_avatars_on_client_id                     (client_id)
#  index_avatars_on_owner_organization_id         (owner_organization_id)
#  index_avatars_on_public_id                     (public_id) UNIQUE
#  index_avatars_on_purged_at                     (purged_at)
#  index_avatars_on_representing_organization_id  (representing_organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (active_handle_id => handles.id)
#  fk_rails_...  (capability_id => avatar_capabilities.id)
#

require "test_helper"

class AvatarTest < ActiveSupport::TestCase
  fixtures :avatar_capabilities, :avatars, :handles

  setup do
    create_user_and_status
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(
      handle: "test_handle-#{SecureRandom.hex(4)}",
      cooldown_until: Time.current,
    )
  end

  test "valid avatar creation" do
    avatar = Avatar.new(
      capability: @capability,
      active_handle: @handle,
      moniker: "Test Client",
      image_data: { url: "http://example.com/img.png" },
    )

    assert_predicate avatar, :valid?
    assert avatar.save
    assert_not_nil avatar.public_id
  end

  test "requires capability" do
    avatar = Avatar.new(active_handle: @handle, moniker: "No Cap", capability_id: nil)

    assert_not avatar.valid?
    assert_not_empty avatar.errors[:capability_id]
  end

  test "requires active_handle" do
    avatar = Avatar.new(capability: @capability, moniker: "No Handle")

    assert_predicate avatar, :valid?
    assert_raises(ActiveRecord::NotNullViolation) { avatar.save! }
  end

  test "requires moniker" do
    avatar = Avatar.new(capability: @capability, active_handle: @handle, moniker: "")

    assert_not avatar.valid?
    assert_not_empty avatar.errors[:moniker]
  end

  test "default image_data is empty hash" do
    avatar = Avatar.create!(
      capability: @capability,
      active_handle: @handle,
      moniker: "Default Image",
    )

    assert_empty(avatar.image_data)
  end

  test "moniker is invalid when only whitespace" do
    avatar = Avatar.new(capability: @capability, active_handle: @handle, moniker: "   ")

    assert_not avatar.valid?
    assert_not_empty avatar.errors[:moniker]
  end

  test "public_id uniqueness" do
    @avatar = Avatar.create!(
      capability: @capability,
      active_handle: @handle,
      moniker: "Public ID Uniqueness Test",
    )
    duplicate = Avatar.new(
      capability: @capability,
      active_handle: @handle,
      moniker: "Another Moniker",
      public_id: @avatar.public_id,
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:public_id]
  end

  test "association deletion: restriction by posts" do
    avatar = Avatar.create!(
      moniker: "AppPost Author",
      capability: @capability,
      active_handle: @handle,
    )
    status = AppPostStatus.find_or_create_by!(id: AppPostStatus::NOTHING)
    AppPost.create!(
      author_avatar: avatar,
      app_post_status: status,
      body: "Test AppPost",
      permalink: "post-author",
      created_by_actor_id: "user-1",
    )

    assert_not avatar.destroy
    assert_not_empty avatar.errors[:base]
  end

  test "create_with_owner creates avatar and assigns owner" do
    create_user_and_status
    user = Client.find_by!(public_id: "one_id")
    avatar = nil
    assert_difference ["Avatar.count", "AvatarAssignment.count"], 1 do
      avatar = Avatar.create_with_owner(
        {
          capability: @capability,
          active_handle: @handle,
          moniker: "Owned Avatar",
        }, user,
      )
    end

    assert_equal user, avatar.owner
    assert_includes avatar.avatar_assignments.pluck(:role), "owner"
  end

  test "role associations" do
    user = Client.find_by!(public_id: "one_id")
    avatar = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Role Test")

    # Affiliation
    avatar.avatar_assignments.create!(user_id: user.id, role: "affiliation")

    assert_equal user, avatar.affiliation_user

    # Operators
    avatar.avatar_assignments.create!(user_id: user.id, role: "administrator")

    assert_includes avatar.administrators, user

    # Editors
    avatar.avatar_assignments.create!(user_id: user.id, role: "editor")

    assert_includes avatar.editors, user

    # Reviewers
    avatar.avatar_assignments.create!(user_id: user.id, role: "reviewer")

    assert_includes avatar.reviewers, user

    # Viewers
    avatar.avatar_assignments.create!(user_id: user.id, role: "viewer")

    assert_includes avatar.viewers, user
  end

  test "social associations: follows" do
    follower = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Follower")
    followed = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Followed")

    follower.outgoing_follows.create!(followed_avatar: followed)

    assert_includes follower.followings, followed
    assert_includes followed.followers, follower
  end

  test "social associations: blocks" do
    blocker = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Blocker")
    blocked = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Blocked")

    blocker.outgoing_blocks.create!(blocked_avatar: blocked)

    assert_includes blocker.blocked_avatars, blocked
  end

  test "social associations: mutes" do
    muter = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Muter")
    muted = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Muted")

    muter.outgoing_mutes.create!(muted_avatar: muted)

    assert_includes muter.muted_avatars, muted
  end

  test "dependent associations" do
    avatar = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Dependent Test")
    user = Client.find_by!(public_id: "one_id")

    # Assignments
    avatar.avatar_assignments.create!(user_id: user.id, role: "viewer")
    # Follows
    other = Avatar.create!(capability: @capability, active_handle: @handle, moniker: "Other")
    avatar.outgoing_follows.create!(followed_avatar: other)
    avatar.incoming_follows.create!(follower_avatar: other)
    # Blocks
    avatar.outgoing_blocks.create!(blocked_avatar: other)
    # Mutes
    avatar.outgoing_mutes.create!(muted_avatar: other)

    assert_difference "AvatarAssignment.count", -1 do
      assert_difference "AvatarFollow.count", -2 do
        assert_difference "AvatarBlock.count", -1 do
          assert_difference "AvatarMute.count", -1 do
            Prosopite.pause { avatar.destroy }
          end
        end
      end
    end
  end

  def create_user_and_status
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    Client.find_or_create_by!(public_id: "one_id") do |u|
      u.status_id = ClientStatus::NOTHING
    end
  end
end
