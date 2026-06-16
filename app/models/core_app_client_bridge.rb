# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: core_app_client_bridges
# Database name: app_zenith
#
#  id           :bigint           not null, primary key
#  audience     :string           default("umaxica-core-app"), not null
#  host         :string           default("www.jp.umaxica.app"), not null
#  lock_version :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  client_id    :bigint           not null
#  public_id    :string           default(""), not null
#  rp_client_id :string           default("core_app"), not null
#
# Indexes
#
#  idx_core_app_client_bridges_unique_client_rp  (client_id,rp_client_id) UNIQUE
#  index_core_app_client_bridges_on_public_id    (public_id) UNIQUE
#
class CoreAppClientBridge < AppRpRecord
  include CoreRpBridge

  belongs_to :client,
             class_name: "Client",
             inverse_of: :core_app_client_bridge

  core_rp_bridge(
    actor_association_name: :client,
    actor_foreign_key: :client_id,
    client_id: "core-next-rp",
    audience: "umaxica-core-app",
    host: "www.jp.umaxica.app",
  )
end
