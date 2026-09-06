# typed: false
# frozen_string_literal: true

module Publishing
  # Input for archiving an entry.
  #
  # The reason is required because `chk_<cell>_ent_archive` requires
  # `archived_at` and `archive_reason` to be set together; an entry cannot be
  # archived anonymously in this schema.
  class ArchiveEntryForm < ApplicationForm
    attribute :reason, :string

    validates :reason, presence: true

    def message_hash
      errors.details.to_h { |attribute, list|
        [attribute, message_for(attribute, list.first.fetch(:error))]
      }
    end

    private

    def message_for(attribute, error)
      if attribute == :reason && error == :blank
        "can't be blank"
      else
        error.to_s
      end
    end
  end
end
