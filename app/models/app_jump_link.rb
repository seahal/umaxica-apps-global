# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_jump_links
# Database name: redirector
#
#  id              :bigint           not null, primary key
#  deletable_at    :datetime         not null
#  destination_url :text             not null
#  max_uses        :integer          default(0), not null
#  policy          :jsonb            not null
#  revoked_at      :datetime         not null
#  uses_count      :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  public_id       :string           not null
#  status_id       :integer          default(0), not null
#
# Indexes
#
#  index_app_jump_links_on_deletable_at  (deletable_at)
#  index_app_jump_links_on_public_id     (public_id) UNIQUE
#  index_app_jump_links_on_status_id     (status_id)
#
class AppJumpLink < RedirectorRecord
  include JumpLinkable

  TLD_HOST = "jump.example.app"
end
