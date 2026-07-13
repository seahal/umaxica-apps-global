# frozen_string_literal: true

require "test_helper"
require Rails.root.join("db/seeds/support/cms_sample_builder")

class CmsSampleSeedTest < ActiveSupport::TestCase
  FAMILIES = %w(AppDocs AppNews AppInfo AppHelp ComDocs ComNews ComInfo ComHelp
                OrgDocs OrgNews OrgInfo OrgHelp).freeze

  test "builder creates complete published samples for all families and is idempotent" do
    FAMILIES.each { |family| assert_family_sample(family) }
  end

  test "sample loader rejects non-development environments" do
    require Rails.root.join("db/seeds/cms_samples")
    error = assert_raises(RuntimeError) { CmsSamples.load! }
    assert_equal "CMS samples are development-only", error.message
  end

  private

  def assert_family_sample(family)
    slug = "#{family.underscore.tr("_", "-")}-sample-test"
    builder = CmsSampleBuilder.new(family:, slug:)

    assert builder.create!
    assert_not builder.create!

    post_class = Object.const_get("#{family}Post", false)
    slug_class = Object.const_get("#{family}PostSlug", false)
    post_slug = slug_class.find_by!(locale: "ja", slug:)
    post = post_class.includes(
      current_revision: %i(revision_category revision_tags),
      versions: %i(version_category version_tags),
    ).find(post_slug.post_id)

    assert_equal "canonical", post_slug.state
    assert_equal 1, post.revisions.count
    assert_equal 1, post.versions.count
    assert_equal 1, post.publications.effective_at(Time.current).count
    assert_predicate post.current_revision.revision_category, :present?
    assert_equal 2, post.current_revision.revision_tags.count
    assert_predicate post.versions.first.version_category, :present?
    assert_equal 2, post.versions.first.version_tags.count
    assert_equal 0, post.media_usages.count
    assert_kind_of Hash, post.current_revision.body
    assert_equal 3, post.current_revision.body.fetch("blocks").size
  end
end
