# typed: false
# frozen_string_literal: true

require "test_helper"

class CmsConcreteModelContractTest < ActiveSupport::TestCase
  SURFACES = { "App" => AppPrincipalRecord, "Com" => ComPrincipalRecord, "Org" => OrgPrincipalRecord }.freeze
  FAMILIES = %w(Docs News Info Help).freeze
  SUFFIXES = %w(Post PostSlug PostRevision PostVersion PostPublication MediaFile MediaUsage Category Tag
                PostRevisionCategory PostRevisionTag PostVersionCategory PostVersionTag).freeze
  TABLE_SUFFIXES = {
    "Post" => "posts",
    "PostSlug" => "post_slugs",
    "PostRevision" => "post_revisions",
    "PostVersion" => "post_versions",
    "PostPublication" => "post_publications",
    "MediaFile" => "media_files",
    "MediaUsage" => "media_usages",
    "Category" => "categories",
    "Tag" => "tags",
    "PostRevisionCategory" => "post_revision_categories",
    "PostRevisionTag" => "post_revision_tags",
    "PostVersionCategory" => "post_version_categories",
    "PostVersionTag" => "post_version_tags",
  }.freeze
  CONCERNS = {
    "Post" => Cms::PostModel,
    "PostSlug" => Cms::PostSlugModel,
    "PostRevision" => Cms::PostRevisionModel,
    "PostVersion" => Cms::PostVersionModel,
    "PostPublication" => Cms::PostPublicationModel,
    "MediaFile" => Cms::MediaFileModel,
    "MediaUsage" => Cms::MediaUsageModel,
    "Category" => Cms::CategoryModel,
    "Tag" => Cms::TagModel,
    "PostRevisionCategory" => Cms::CategoryAssignmentModel,
    "PostRevisionTag" => Cms::TagAssignmentModel,
    "PostVersionCategory" => Cms::CategoryAssignmentModel,
    "PostVersionTag" => Cms::TagAssignmentModel,
  }.freeze

  test "all 156 models use the surface principal base, explicit table, and expected concern" do
    SURFACES.each do |surface, base|
      FAMILIES.each do |family|
        SUFFIXES.each do |suffix|
          model = "#{surface}#{family}#{suffix}".constantize

          assert_operator model, :<, base
          assert_equal "#{surface.downcase}_#{family.downcase}_#{TABLE_SUFFIXES.fetch(suffix)}", model.table_name
          assert_includes model.ancestors, CONCERNS.fetch(suffix)
          assert_includes model.ancestors, PublicId
        end
      end
    end
  end

  test "all families expose explicit association contracts" do
    SURFACES.each_key do |surface|
      FAMILIES.each do |family|
        prefix = "#{surface}#{family}"
        expected = {
          "Post" => { current_revision: ["#{prefix}PostRevision", "current_revision_id", :current_for_post, nil],
                      slugs: ["#{prefix}PostSlug", "post_id", :post, :restrict_with_exception],
                      revisions: ["#{prefix}PostRevision", "post_id", :post, :restrict_with_exception],
                      versions: ["#{prefix}PostVersion", "post_id", :post, :restrict_with_exception],
                      publications: ["#{prefix}PostPublication", "post_id", :post, :restrict_with_exception], },
          "PostSlug" => { post: ["#{prefix}Post", "post_id", :slugs, nil] },
          "PostRevision" => { post: ["#{prefix}Post", "post_id", :revisions, nil],
                              restored_from_revision: ["#{prefix}PostRevision", "restored_from_revision_id", :restored_revisions, nil],
                              restored_from_version: ["#{prefix}PostVersion", "restored_from_version_id", :restored_revisions, nil],
                              version: ["#{prefix}PostVersion", "post_revision_id", :post_revision, :restrict_with_exception],
                              media_usages: ["#{prefix}MediaUsage", "post_revision_id", :post_revision, :restrict_with_exception],
                              revision_category: ["#{prefix}PostRevisionCategory", "post_revision_id", :post_revision, :restrict_with_exception],
                              revision_tags: ["#{prefix}PostRevisionTag", "post_revision_id", :post_revision, :restrict_with_exception], },
          "PostVersion" => { post: ["#{prefix}Post", "post_id", :versions, nil],
                             post_revision: ["#{prefix}PostRevision", "post_revision_id", :version, nil],
                             publications: ["#{prefix}PostPublication", "post_version_id", :post_version, :restrict_with_exception],
                             media_usages: ["#{prefix}MediaUsage", "post_version_id", :post_version, :restrict_with_exception],
                             version_category: ["#{prefix}PostVersionCategory", "post_version_id", :post_version, :restrict_with_exception],
                             version_tags: ["#{prefix}PostVersionTag", "post_version_id", :post_version, :restrict_with_exception], },
          "PostPublication" => { post: ["#{prefix}Post", "post_id", :publications, nil],
                                 post_version: ["#{prefix}PostVersion", "post_version_id", :publications, nil], },
          "MediaFile" => { media_usages: ["#{prefix}MediaUsage", "media_file_id", :media_file, :restrict_with_exception] },
          "MediaUsage" => { media_file: ["#{prefix}MediaFile", "media_file_id", :media_usages, nil],
                            post: ["#{prefix}Post", "post_id", :media_usages, nil],
                            post_revision: ["#{prefix}PostRevision", "post_revision_id", :media_usages, nil],
                            post_version: ["#{prefix}PostVersion", "post_version_id", :media_usages, nil], },
          "Category" => { parent: ["#{prefix}Category", "parent_id", :children, nil],
                          children: ["#{prefix}Category", "parent_id", :parent, :restrict_with_exception], },
          "Tag" => {},
          "PostRevisionCategory" => { post_revision: ["#{prefix}PostRevision", "post_revision_id", :revision_category, nil],
                                      category: ["#{prefix}Category", "category_id", :revision_assignments, nil], },
          "PostRevisionTag" => { post_revision: ["#{prefix}PostRevision", "post_revision_id", :revision_tags, nil],
                                 tag: ["#{prefix}Tag", "tag_id", :revision_assignments, nil], },
          "PostVersionCategory" => { post_version: ["#{prefix}PostVersion", "post_version_id", :version_category, nil],
                                     category: ["#{prefix}Category", "category_id", :version_assignments, nil], },
          "PostVersionTag" => { post_version: ["#{prefix}PostVersion", "post_version_id", :version_tags, nil],
                                tag: ["#{prefix}Tag", "tag_id", :version_assignments, nil], },
        }

        expected.each do |suffix, associations|
          model = "#{prefix}#{suffix}".constantize
          associations.each do |name, (class_name, foreign_key, inverse_of, dependent)|
            reflection = model.reflect_on_association(name)

            assert reflection, "#{model.name} must define #{name}"
            assert_equal class_name, reflection.class_name
            assert_equal foreign_key, reflection.foreign_key
            assert_equal inverse_of, reflection.options[:inverse_of]
            if dependent.nil?
              assert_nil reflection.options[:dependent]
            else
              assert_equal dependent, reflection.options[:dependent]
            end
          end
        end
      end
    end
  end

  test "taxonomy, immutability, and media naming boundaries remain explicit" do
    SURFACES.each_key do |surface|
      FAMILIES.each do |family|
        prefix = "#{surface}#{family}"

        assert "#{prefix}Category".constantize.reflect_on_association(:parent)
        assert "#{prefix}Category".constantize.reflect_on_association(:children)
        assert_nil "#{prefix}Tag".constantize.reflect_on_association(:parent)
        assert_nil "#{prefix}Tag".constantize.reflect_on_association(:children)
        %w(PostRevision PostVersion MediaUsage PostRevisionCategory PostRevisionTag PostVersionCategory PostVersionTag).each do |suffix|
          assert_includes "#{prefix}#{suffix}".constantize.ancestors, Cms::ImmutableRecord
        end
        assert Object.const_defined?("#{prefix}MediaFile")
        assert Object.const_defined?("#{prefix}MediaUsage")
        assert_not Object.const_defined?("#{prefix}Asset")
        assert_not "#{prefix}MediaFile".constantize.ancestors.any? { |ancestor| ancestor.name&.include?("Shrine") }
      end
    end
  end

  test "the model slice does not add delivery controllers routes or upload adapters" do
    assert_empty Rails.root.glob("app/controllers/{app,com,org}_{docs,news,info,help}_*")
    assert_empty Rails.root.glob("app/uploaders/**/*")
  end
end
