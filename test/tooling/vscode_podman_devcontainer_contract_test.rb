# frozen_string_literal: true

require "json"
require "minitest/autorun"

class VscodePodmanDevcontainerContractTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)

  def test_repository_recommends_the_dev_containers_extension
    extensions = JSON.parse(File.read(File.join(REPOSITORY_ROOT, ".vscode/extensions.json")))

    assert_includes extensions.fetch("recommendations"), "ms-vscode-remote.remote-containers"
  end

  def test_vscode_startup_contract_uses_podman_without_a_repository_launcher
    documentation = File.read(
      File.join(REPOSITORY_ROOT, "docs/operations/devcontainer-cli-podman-startup.md"),
    )

    refute_path_exists File.join(REPOSITORY_ROOT, "podman/tools/dcup")
    assert_includes documentation, '"dev.containers.dockerPath": "/usr/bin/podman"'
    assert_includes documentation, '"dev.containers.dockerComposePath": "/usr/bin/podman-compose"'
    assert_includes documentation, 'compose_providers = ["/usr/bin/podman-compose"]'
    assert_includes documentation, "Dev Containers: Rebuild and Reopen in Container"
  end
end
