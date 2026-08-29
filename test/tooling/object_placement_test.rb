# frozen_string_literal: true

require "minitest/autorun"
require "set"

# Guards .agents/harnesses/rules/project/value-object-boundaries.mdc.
#
# `app/services` had become a support root rather than a layer: 236 files carrying 115 distinct
# name suffixes, of which only 9 ended in `service`. Nothing distinguished a service from anything
# else filed beside it, because only 46 of those files inherit ApplicationService and the root is
# flat, so neither the type nor the path carried the role.
#
# This test pins the half of the placement rule that is mechanically checkable: a suffix owned by
# another root must not appear under `app/services`. It reads the filesystem rather than loading
# Rails, so it runs without a database or the compose environment.
#
# PENDING lists the files still awaiting their migration issue. Shrinking it is the point: each
# migration issue deletes its entries, which turns this test red until the files actually move.
# Do not add entries to make the suite green - see project/regression-guards.mdc.
class ObjectPlacementTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)

  # A suffix and the single root that owns it. Only unambiguous suffixes belong here; roles such as
  # `Issuer`, which names both a persisting operation and a pure token minter, are decided per file
  # in memos/2026-08-29-object-placement-inventory.md rather than by name.
  OWNED_SUFFIXES = {
    "consumer" => "app/consumers",
    "query" => "app/queries",
    "resolver" => "app/resolvers",
    "serializer" => "app/serializers",
  }.freeze

  # Files that still sit in the wrong root, each with the issue that moves it. Entries are removed
  # by that issue, not to quiet a failure.
  PENDING = {
    # #864 - queries and resolvers
    "app/services/publishing_published_entries_query.rb" => 864,
    "app/services/host_context_resolver.rb" => 864,
    "app/services/publishing_edition_resolver.rb" => 864,
    "app/services/redirects_external_target_resolver.rb" => 864,
    "app/services/redirects_navigation_target_resolver.rb" => 864,
    "app/services/redirects_path_target_resolver.rb" => 864,
    "app/services/redirects_priority_resolver.rb" => 864,
    "app/services/sign_in_activation_candidate_resolver.rb" => 864,
    "app/services/webauthn/authenticator_name_resolver.rb" => 864,
    "app/policies/step_up_methods_resolver.rb" => 864,
    "app/policies/step_up_resolver.rb" => 864,
    "app/values/account_standing_resolver.rb" => 864,
    "app/values/oidc_client_secret_resolver.rb" => 864,
    "app/lib/external_sign_in/org_entra_resolver.rb" => 864,
    # #863 - serializers
    "app/services/publishing_entry_serializer.rb" => 863,
    "app/values/webauthn/options_serializer.rb" => 863,
  }.freeze

  # Concerns live under a concerns root, which is already the classifier, so the suffix rule does
  # not reach them. See value-object-boundaries.mdc, "Exceptions to the suffix rule".
  CONCERN_ROOTS = %r{(\A|/)concerns/}

  def test_no_file_carries_a_suffix_owned_by_another_root
    offenders =
      ruby_files_under("app").reject { |path| PENDING.key?(path) || path.match?(CONCERN_ROOTS) }.filter_map do |path|
        suffix = File.basename(path, ".rb").split("_").last
        owner = OWNED_SUFFIXES[suffix]
        next if owner.nil?
        next if path.start_with?("#{owner}/")

        "#{path} carries the `#{suffix}` suffix, which belongs to #{owner}"
      end

    assert_empty offenders,
                 "Filed under a root that does not own the role suffix " \
                 "(see value-object-boundaries.mdc):\n#{offenders.join("\n")}"
  end

  # Constants defined under app/services that app/models still reaches for, each with the issue
  # that resolves it. A Service orchestrates models, so this arrow must not exist.
  MODEL_DEPENDENCIES_PENDING = {
    # #869 - audit writes fired from a model callback, and the retention/sanitization helpers
    # that sit in the same group
    "ChronicleIntentWriter" => 869,
    "ChronicleResultWriter" => 869,
    "ChronicleInvalidator" => 869,
    "ChronicleFallbackRecorder" => 869,
    "ChronicleRecorder" => 869,
    # #869 - AdministrativeAccessLock.lock!/.unlock! called from a model concern
    "AdministrativeAccessLock" => 869,
  }.freeze

  def test_models_do_not_depend_on_app_services
    defined_in_services =
      ruby_files_under("app/services").to_set do |path|
        path.delete_prefix("app/services/").delete_suffix(".rb").split(%r{[/_]}).map(&:capitalize).join
      end

    referenced =
      ruby_files_under("app/models").flat_map do |path|
        File.read(File.join(REPOSITORY_ROOT, path))
          .gsub(/#.*/, "")
          .scan(/\b[A-Z][A-Za-z0-9]+\b/)
      end.to_set

    offenders =
      (defined_in_services & referenced)
        .reject { |constant| MODEL_DEPENDENCIES_PENDING.key?(constant) }
        .sort

    assert_empty offenders,
                 "app/models depends on constants defined under app/services " \
                 "(see value-object-boundaries.mdc, Dependency direction):\n#{offenders.join("\n")}"
  end

  def test_pending_entries_still_exist
    missing = PENDING.keys.reject { |path| File.exist?(File.join(REPOSITORY_ROOT, path)) }

    assert_empty missing,
                 "PENDING names files that no longer exist, so this guard no longer checks " \
                 "them:\n#{missing.join("\n")}"
  end

  private

  def ruby_files_under(directory)
    Dir.glob(File.join(REPOSITORY_ROOT, directory, "**", "*.rb")).map do |path|
      path.delete_prefix("#{REPOSITORY_ROOT}/")
    end.sort
  end
end
