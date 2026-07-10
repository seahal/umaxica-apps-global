# typed: false
# frozen_string_literal: true

namespace :identity_graph do
  desc "Repair missing selector-ready identity graphs"
  task repair: :environment do
    surface = ENV.fetch("SURFACE").to_sym
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "false"))

    result = IdentityGraphRepair.run(surface: surface, dry_run: dry_run)

    puts(
      [
        "identity_graph_repair",
        "surface=#{result[:surface]}",
        "dry_run=#{result[:dry_run]}",
        "checked=#{result[:checked]}",
        "missing=#{result[:missing]}",
        "repaired=#{result[:repaired]}",
        "failed=#{result[:failed]}",
      ].join(" "),
    )
  end
end

module IdentityGraphRepair
  module_function

  def run(surface:, dry_run:)
    config = AcmeSelector.config_for(surface)
    checked = 0
    missing = 0
    repaired = 0
    failed = 0

    config.principal_class.find_each do |principal|
      checked += 1
      next if selector_ready_graph?(config, principal)

      missing += 1
      if dry_run
        next
      end

      begin
        IdentityGraphProvisioner.call!(surface: surface, principal: principal)
        repaired += 1
      rescue StandardError => e
        failed += 1
        Rails.logger.error(
          JitLogEvent.format(
            "identity.graph_repair.failed",
            surface: surface,
            principal_class: principal.class.name,
            principal_id: principal.id,
            error_class: e.class.name,
            error_message: e.message,
          ),
        )
      end
    end

    {
      surface: surface,
      dry_run: dry_run,
      checked: checked,
      missing: missing,
      repaired: repaired,
      failed: failed,
    }
  end

  def selector_ready_graph?(config, principal)
    identity = config.identity_class.find_by(source_record_id: principal.id)
    return false unless identity

    account = identity.public_send(config.account_class.name.underscore)
    return false unless account
    return false unless account.current_memberships.active.exists?

    return true unless config.requires_avatar

    AvatarAssignment.exists?(user_id: principal.id, role: "owner")
  end
end
