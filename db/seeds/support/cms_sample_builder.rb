# frozen_string_literal: true

# Creates one immutable, published development sample without using HTTP authorization paths.
class CmsSampleBuilder
  LOCALE = "ja"
  OPERATOR_PUBLIC_ID = "2222222222222222"

  def initialize(family:, slug:)
    @family = family
    @slug = slug
  end

  def create!
    return false if slug_class.exists?(locale: LOCALE, slug: @slug)

    post_class.transaction do
      post = post_class.create!(locale: LOCALE)
      slug_class.create!(post:, locale: LOCALE, slug: @slug, state: "canonical", canonicalized_at: Time.current)
      revision = revision_class.create!(post:, **content_attributes, sequence: 1, **provenance)
      post.update!(current_revision: revision)
      version = version_class.create!(post:, post_revision: revision, **content_attributes, sequence: 1, **provenance)
      publication_class.create!(post:, post_version: version, effective_from: 1.minute.ago, **provenance)
      category = category_class.create!(
        locale: LOCALE, slug: "#{@slug}-category", name: "#{title} Category", position: 0,
        depth: 0,
      )
      create_category_assignments(revision, version, category)
      create_tag_assignments(revision, version)
    end
    true
  end

  private

  def create_category_assignments(revision, version, category)
    snapshot = taxonomy_snapshot(category)
    revision_category_class.create!(post_revision: revision, category:, **snapshot)
    version_category_class.create!(post_version: version, category:, **snapshot)
  end

  def create_tag_assignments(revision, version)
    %w(sample development).each_with_index do |suffix, position|
      tag = tag_class.create!(locale: LOCALE, slug: "#{@slug}-#{suffix}", name: "#{title} #{suffix.titleize}")
      snapshot = taxonomy_snapshot(tag).merge(position:)
      revision_tag_class.create!(post_revision: revision, tag:, **snapshot)
      version_tag_class.create!(post_version: version, tag:, **snapshot)
    end
  end

  def taxonomy_snapshot(term)
    {
      locale: LOCALE,
      taxonomy_public_id_snapshot: term.public_id,
      slug_snapshot: term.slug,
      name_snapshot: term.name,
      path_snapshot: [],
      created_at: Time.current,
    }
  end

  def content_attributes
    { locale: LOCALE, title:, summary: "Development-only CMS sample.", schema_version: 1, body: body }
  end

  def body
    {
      "schema_version" => 1,
      "blocks" => [
        { "type" => "heading", "level" => 1, "text" => title },
        # rubocop:disable I18n/RailsI18n/DecorateString -- development seed content is intentionally fixed English.
        { "type" => "paragraph", "text" => "This is development-only sample content." },
        { "type" => "callout", "variant" => "info", "body" => "Created by SEED_CMS_SAMPLES=1." },
        # rubocop:enable I18n/RailsI18n/DecorateString
      ],
    }
  end

  def title = @family.underscore.humanize.titleize

  def provenance = { created_by_operator_public_id: OPERATOR_PUBLIC_ID }

  def post_class = family_class("Post")

  def slug_class = family_class("PostSlug")

  def revision_class = family_class("PostRevision")

  def version_class = family_class("PostVersion")

  def publication_class = family_class("PostPublication")

  def category_class = family_class("Category")

  def tag_class = family_class("Tag")

  def revision_category_class = family_class("PostRevisionCategory")

  def version_category_class = family_class("PostVersionCategory")

  def revision_tag_class = family_class("PostRevisionTag")

  def version_tag_class = family_class("PostVersionTag")

  def family_class(suffix)
    Object.const_get("#{@family}#{suffix}", false)
  end
end
