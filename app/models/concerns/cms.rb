# typed: false
# frozen_string_literal: true

# Stable CMS namespace backed by flat concern constants required by repository layout policy.
module Cms
  ROOT = Rails.root.join("app/models/concerns")

  autoload :Archivable, ROOT.join("cms_archivable.rb")
  autoload :CategoryAssignmentModel, ROOT.join("cms_category_assignment_model.rb")
  autoload :CategoryModel, ROOT.join("cms_category_model.rb")
  autoload :ImmutableRecord, ROOT.join("cms_immutable_record.rb")
  autoload :MediaFileModel, ROOT.join("cms_media_file_model.rb")
  autoload :MediaUsageModel, ROOT.join("cms_media_usage_model.rb")
  autoload :OperatorProvenance, ROOT.join("cms_operator_provenance.rb")
  autoload :OwnershipRules, ROOT.join("cms_ownership_rules.rb")
  autoload :PostModel, ROOT.join("cms_post_model.rb")
  autoload :PostPublicationModel, ROOT.join("cms_post_publication_model.rb")
  autoload :PostRevisionModel, ROOT.join("cms_post_revision_model.rb")
  autoload :PostSlugModel, ROOT.join("cms_post_slug_model.rb")
  autoload :PostVersionModel, ROOT.join("cms_post_version_model.rb")
  autoload :PublicationPredicates, ROOT.join("cms_publication_predicates.rb")
  autoload :SlugRules, ROOT.join("cms_slug_rules.rb")
  autoload :StructuredBody, ROOT.join("cms_structured_body.rb")
  autoload :TagAssignmentModel, ROOT.join("cms_tag_assignment_model.rb")
  autoload :TagModel, ROOT.join("cms_tag_model.rb")
  autoload :TaxonomyAssignmentModel, ROOT.join("cms_taxonomy_assignment_model.rb")
  autoload :TaxonomyNormalization, ROOT.join("cms_taxonomy_normalization.rb")
  autoload :TaxonomyTermModel, ROOT.join("cms_taxonomy_term_model.rb")
end
