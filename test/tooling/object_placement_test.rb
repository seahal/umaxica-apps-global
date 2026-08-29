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
  PENDING = {}.freeze

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

  # Roots whose contents must end in one of the root's allowed suffixes, so that a file names its
  # own role the way xxx_controller.rb does. Only roots that are fully compliant are listed; the
  # remainder are added as their migration issue makes them so.
  #
  # Not yet listed, with the reason:
  #   app/services   - #868 has not run; the root is still mixed
  #   app/policies   - three files need a rule decision (sign_up_step_gate, quota_limits,
  #                    step_up_available_methods)
  #   app/adapters   - MCP tools and provider/cache names need a rule decision
  #   app/lib        - ports and primitives, suffix set not settled
  #   app/values     - 96 files grandfathered until #870
  ROOT_SUFFIXES = {
    "app/consumers" => %w(consumer),
    "app/forms" => %w(form),
    "app/notifiers" => %w(notifier),
    "app/operations" => %w(operation),
    "app/presenters" => %w(presenter),
    "app/queries" => %w(query inventory locator),
    "app/resolvers" => %w(resolver),
    "app/serializers" => %w(serializer),
    "app/subscribers" => %w(subscriber),
    "app/validators" => %w(validator),
  }.freeze

  # An error namespace holds Error classes rather than being one, so it cannot carry the suffix
  # without the constant lying about what it is.
  SUFFIX_EXEMPT = ["app/errors/identity_telephone_ceremony.rb"].freeze

  def test_every_file_names_its_own_role
    offenders =
      ROOT_SUFFIXES.flat_map do |root, suffixes|
        ruby_files_under(root).reject { |path| SUFFIX_EXEMPT.include?(path) }.filter_map do |path|
          suffix = File.basename(path, ".rb").split("_").last
          next if suffixes.include?(suffix)

          "#{path} does not end in #{suffixes.join(", ")}"
        end
      end

    assert_empty offenders,
                 "Files in a role root do not name their role " \
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
