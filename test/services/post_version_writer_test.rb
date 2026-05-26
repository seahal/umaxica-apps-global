# typed: false
# frozen_string_literal: true

require "test_helper"

class PostVersionWriterTest < ActiveSupport::TestCase
  TestEditor = Struct.new(:id)

  setup do
    capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    handle =
      Handle.find_or_create_by!(handle: "post_version_writer_test") { |record|
        record.cooldown_until = Time.current
      }
    @avatar =
      Avatar.find_or_create_by!(moniker: "Post Version Writer Author") do |record|
        record.capability = capability
        record.active_handle = handle
      end
  end

  test "writes app post version" do
    post = create_post(Post, PostStatus)

    version = nil
    assert_difference "PostVersion.count", 1 do
      version = PostVersionWriter.write!(post, attrs: { title: "Title", description: "Desc", body: "Body" })
    end

    assert_equal post, version.post
    assert_equal "Title", version.title
    assert_equal "Desc", version.description
    assert_equal "Body", version.body
  end

  test "writes com post version" do
    post = create_post(ComPost, ComPostStatus)

    version = nil
    assert_difference "ComPostVersion.count", 1 do
      version = PostVersionWriter.write!(post, attrs: { title: "Title", description: "Desc", body: "Body" })
    end

    assert_equal post, version.post
    assert_equal "Title", version.title
  end

  test "writes org post version" do
    post = create_post(OrgPost, OrgPostStatus)

    version = nil
    assert_difference "OrgPostVersion.count", 1 do
      version = PostVersionWriter.write!(post, attrs: { title: "Title", description: "Desc", body: "Body" })
    end

    assert_equal post, version.post
    assert_equal "Title", version.title
  end

  test "raises argument error for unsupported post type" do
    unsupported = Object.new

    assert_raises(ArgumentError) do
      PostVersionWriter.write!(unsupported, attrs: { title: "Title", description: "Desc", body: "Body" })
    end
  end

  test "writes version with editor metadata" do
    post = create_post(Post, PostStatus)
    editor = TestEditor.new(123)

    version = PostVersionWriter.write!(
      post,
      attrs: { title: "Title", description: "Desc", body: "Body" },
      editor: editor,
    )

    assert_equal editor.class.name, version.edited_by_type
    assert_equal 123, version.edited_by_id
  end

  private

  def create_post(post_class, status_class)
    status = status_class.find_or_create_by!(id: status_class::NOTHING)
    post_class.create!(
      author_avatar: @avatar,
      post_status: status,
      body: "Version writer post body",
      created_by_actor_id: 1,
    )
  end
end
