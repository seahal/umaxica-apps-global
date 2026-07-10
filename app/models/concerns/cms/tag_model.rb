# typed: false
# frozen_string_literal: true

module Cms
  module TagModel
    extend ActiveSupport::Concern
    include Cms::TaxonomyTermModel

    class_methods do
      def cms_tag_model(revision_assignment_class_name:, version_assignment_class_name:)
        has_many :revision_assignments, class_name: revision_assignment_class_name, foreign_key: :tag_id,
                                        inverse_of: :tag, dependent: :restrict_with_exception
        has_many :version_assignments, class_name: version_assignment_class_name, foreign_key: :tag_id,
                                       inverse_of: :tag, dependent: :restrict_with_exception
      end
    end
  end
end
