# typed: false
# frozen_string_literal: true

require "test_helper"

# Structural guards on the locale bundles themselves.
#
# Two silencers previously let missing translations reach production: duplicate YAML mapping keys,
# which discard the earlier block without any warning, and `t(..., default: ...)` call sites, which
# suppress the exception `config.i18n.raise_on_missing_translations` exists to raise. Both are
# invisible in review, so they are asserted here rather than left to a reader's attention.
class LocaleBundleIntegrityTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  LOCALE_ROOT = Rails.root.join("config/locales")
  APPLICATION_ROOT = Rails.root.join("app")

  # `t("key", default: ...)` and `I18n.t("key", default: ...)`. `default:` on any other method
  # (credentials lookups, form helpers, ActiveRecord options) is unrelated and not matched.
  TRANSLATE_WITH_DEFAULT = /(?<![a-z_])(?:I18n\.)?t(?:ranslate)?\([^\n]*?\bdefault:/

  test "no locale bundle defines the same key twice" do
    duplicates =
      locale_bundles.flat_map do |path|
        duplicate_keys(Psych.parse(path.read)).map { |key, first, second| "#{path.basename}: #{key} (line #{first} then #{second})" }
      end

    assert_empty duplicates,
                 "A duplicate YAML key silently discards the earlier block:\n#{duplicates.join("\n")}"
  end

  # Rails' own i18n railtie re-appends config/locales after the initializers run, so a bundle can
  # legitimately appear on the load path more than once. What matters is that none is absent.
  test "every locale bundle under config/locales is on the load path" do
    on_load_path = I18n.load_path.map(&:to_s).select { |path| path.start_with?(LOCALE_ROOT.to_s) }

    assert_equal locale_bundles.map(&:to_s).sort, on_load_path.uniq.sort,
                 "A bundle that is not on the load path is silently ignored at runtime"
  end

  test "application code never suppresses a missing translation with default:" do
    offenders = application_sources.filter_map do |path|
      lines =
        path.read.lines.each_with_index.filter_map do |line, index|
          "#{path.relative_path_from(Rails.root)}:#{index + 1}: #{line.strip}" if line.match?(TRANSLATE_WITH_DEFAULT)
        end
      lines.presence
    end.flatten

    assert_empty offenders,
                 "`default:` stops raise_on_missing_translations from ever firing; add the key instead:\n" \
                 "#{offenders.join("\n")}"
  end

  private

  def locale_bundles
    Pathname.glob(LOCALE_ROOT.join("**", "*.yml")).sort
  end

  def application_sources
    Pathname.glob(APPLICATION_ROOT.join("**", "*.{rb,erb}")).sort
  end

  def duplicate_keys(node, path = "")
    return [] if node.nil?

    case node
    when Psych::Nodes::Document, Psych::Nodes::Stream
      node.children.flat_map { |child| duplicate_keys(child, path) }
    when Psych::Nodes::Sequence
      node.children.each_with_index.flat_map { |child, index| duplicate_keys(child, "#{path}[#{index}]") }
    when Psych::Nodes::Mapping
      seen = {}
      node.children.each_slice(2).flat_map do |key_node, value_node|
        key = key_node.value
        child_path = path.empty? ? key : "#{path}.#{key}"
        found = seen.key?(key) ? [[child_path, seen[key], key_node.start_line + 1]] : []
        seen[key] = key_node.start_line + 1
        found + duplicate_keys(value_node, child_path)
      end
    else
      []
    end
  end
end
