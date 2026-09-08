# typed: false
# frozen_string_literal: true

module Publishing
  # Input for a staff CMS revision of an existing entry: the shared content
  # fields plus the optimistic lock the operator's page was rendered from.
  class ReviseEntryForm < EntryContentForm
    attribute :lock_version, :integer
  end
end
