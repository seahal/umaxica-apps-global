# typed: false
# frozen_string_literal: true

require "test_helper"
require "json"
require "yaml"

module Security
  class DevcontainerMountContractTest < ActiveSupport::TestCase
    test "Claude and Codex writable state use named volumes instead of host binds" do
      source = Rails.root.join(".devcontainer/devcontainer.json").read
      devcontainer = JSON.parse(source.gsub(/^\s*\/\/.*$/, ""))

      mounts_by_target =
        devcontainer.fetch("mounts").to_h do |mount|
          attributes = mount.split(",").to_h { |entry| entry.split("=", 2) }
          [attributes.fetch("target"), attributes]
        end

      assert_equal(
        { "source" => "global-claude", "target" => "/home/global/.claude", "type" => "volume" },
        mounts_by_target.fetch("/home/global/.claude"),
      )
      assert_equal(
        { "source" => "global-codex", "target" => "/home/global/.codex", "type" => "volume" },
        mounts_by_target.fetch("/home/global/.codex"),
      )
      assert_not mounts_by_target.key?("/home/global/.claude.json"),
                 "Claude's home-level state file must not be a writable host bind"
    end

    test "dependency manifests inherit the writable workspace mount" do
      compose = YAML.unsafe_load_file(Rails.root.join(".devcontainer/compose.override.yml"))
      volumes = compose.fetch("services").fetch("core").fetch("volumes")
      mounted_targets = volumes.filter_map { |volume| volume["target"] if volume.is_a?(Hash) }

      assert_not_includes mounted_targets, "/home/global/workspace/Gemfile"
      assert_not_includes mounted_targets, "/home/global/workspace/Gemfile.lock"
      assert_not_includes mounted_targets, "/home/global/workspace/package.json"
    end

    test "supply-chain control directories remain read-only binds" do
      compose = YAML.unsafe_load_file(Rails.root.join(".devcontainer/compose.override.yml"))
      volumes = compose.fetch("services").fetch("core").fetch("volumes")
      volumes_by_target = volumes.filter_map do |volume|
        [volume["target"], volume] if volume.is_a?(Hash) && volume["target"]
      end.to_h

      %w(
        /home/global/workspace/.github
        /home/global/workspace/bin
        /home/global/workspace/.devcontainer
      ).each do |target|
        mount = volumes_by_target.fetch(target)

        assert_equal "bind", mount.fetch("type")
        assert mount.fetch("read_only")
      end
    end
  end
end
