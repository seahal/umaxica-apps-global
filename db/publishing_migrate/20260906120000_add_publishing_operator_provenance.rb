# frozen_string_literal: true

require_relative "../migration_support/publishing_schema"

# Records which operator archived an entry and which one ended a publication.
#
# Revisions, versions, and publications already carry
# `created_by_operator_public_id`, so every row that *appears* names its
# author. The two transitions that make content disappear -- archiving an
# entry and ending a publication window -- named nobody, and application logs
# are not the authoritative record for that kind of event
# (`adr/application-logging-boundary.md`).
#
# One column covers both endings a publication has: `cancelled_at` before it
# takes effect and `terminated_at` after. Which one applies is already
# decided by `chk_<cell>_pub_cancel` and `chk_<cell>_pub_term`; the operator
# is the same fact either way.
class AddPublishingOperatorProvenance < ActiveRecord::Migration[8.2]
  def change
    PublishingSchema::FAMILIES.each do |surface, audience|
      prefix = "publishing_#{surface}_#{audience}"

      add_column("#{prefix}_entries", :archived_by_operator_public_id, :string, limit: 21)
      add_column("#{prefix}_publications", :ended_by_operator_public_id, :string, limit: 21)
    end
  end
end
