# frozen_string_literal: true

module Publishing
  module EntryVersionRecord
    extend ActiveSupport::Concern

    included do
      include PublicId
      include Publishing::EncryptedContent

      before_update { raise(ActiveRecord::ReadOnlyRecord, "#{self.class.name} is immutable") }
      before_destroy { raise(ActiveRecord::ReadOnlyRecord, "#{self.class.name} is immutable") }

      family = name.deconstantize
      belongs_to :entry, class_name: "#{family}::Entry", inverse_of: :versions
      belongs_to :entry_revision, class_name: "#{family}::EntryRevision"
      has_many :publications, class_name: "#{family}::Publication", inverse_of: :entry_version,
                              dependent: :restrict_with_exception
      has_many :media_usages, class_name: "#{family}::VersionMediaUsage", inverse_of: :entry_version,
                              dependent: :restrict_with_exception
      has_many :single_taxonomy_assignments, class_name: "#{family}::VersionSingleTaxonomyAssignment",
                                             inverse_of: :entry_version, dependent: :restrict_with_exception
      has_many :multiple_taxonomy_assignments, -> { ordered },
               class_name: "#{family}::VersionMultipleTaxonomyAssignment",
               inverse_of: :entry_version, dependent: :restrict_with_exception
    end
  end
end
