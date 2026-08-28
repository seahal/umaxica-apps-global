# frozen_string_literal: true

require "test_helper"

class DevelopmentContainerContractTest < ActiveSupport::TestCase
  REPOSITORY_ROOT = Rails.root
  CONFIGURATION_FILES = %w(compose.yaml compose.custom.yaml compose.remote-access.yaml).freeze

  test "repository uses Containerfile build definitions exclusively" do
    dockerfiles = `git ls-files '*Dockerfile*'`.lines.map(&:strip).reject(&:empty?)

    assert_empty dockerfiles, "repository-owned Dockerfiles: #{dockerfiles.join(", ")}"
    assert_predicate REPOSITORY_ROOT.join("Containerfile"), :file?
  end

  test "local secrets are excluded from Git and both build contexts" do
    assert system("git", "check-ignore", "--quiet", ".secrets/contract-probe")

    %w(.containerignore .dockerignore).each do |path|
      patterns = REPOSITORY_ROOT.join(path).read.lines.map(&:strip)

      assert_includes patterns, ".secrets/", "#{path} must exclude .secrets/"
    end
  end

  test "compose configuration excludes forbidden host and privilege shortcuts" do
    configuration = CONFIGURATION_FILES.filter_map do |path|
      file = REPOSITORY_ROOT.join(path)
      file.read if file.exist?
    end.join("\n")

    forbidden = {
      "host credential mount" => %r{source:\s*["']?\$\{HOME[^\n]*(?:\.ssh|\.gnupg|\.config/(?:gh|opencode)|\.claude|\.codex|\.gitconfig)},
      "SSH agent forwarding" => /SSH_AUTH_SOCK/,
      "container engine socket" => %r{(?:docker|podman)\.sock},
      "privileged mode" => /^\s*privileged:\s*true\s*$/,
      "host networking" => /^\s*network_mode:\s*host\s*$/,
      "explicit shared memory size" => /^\s*shm_size:/,
    }

    forbidden.each do |description, pattern|
      assert_no_match pattern, configuration, description
    end
  end

  test "Containerfiles do not declare or copy credentials" do
    containerfiles = Dir.glob(REPOSITORY_ROOT.join("**/Containerfile"))
    credential_name = /(?:PASSWORD|SECRET|TOKEN|API_KEY|PRIVATE_KEY|AUTH_SOCK)/i

    containerfiles.each do |path|
      contents = File.read(path)

      assert_not contents.lines.any? { |line| line.match?(/^\s*(?:ARG|ENV)\s+.*#{credential_name}/) }, path
      assert_no_match(/^\s*COPY\s+.*(?:\.secrets|\.ssh|\.gnupg|\.config\/(?:gh|opencode)|\.claude|\.codex)/i, contents, path)
    end
  end

  test "devcontainer uses the standard CLI lifecycle without a repository launcher" do
    devcontainer = REPOSITORY_ROOT.join(".devcontainer/devcontainer.json").read

    assert_not_predicate REPOSITORY_ROOT.join("podman/tools/dcup"), :exist?
    assert_includes devcontainer, "bin/setup-dev-secrets"
    assert_not_includes devcontainer, "ensure-shared-networks"
  end

  test "the development container carries no Tailscale" do
    devcontainer = REPOSITORY_ROOT.join(".devcontainer/devcontainer.json").read
    containerfile = REPOSITORY_ROOT.join("Containerfile").read

    assert_no_match(/tailscale/i, devcontainer)
    assert_no_match(/tailscale/i, containerfile)
    assert_not_predicate REPOSITORY_ROOT.join(".devcontainer/tailscale-core-supervisor.sh"), :exist?
    assert_not_predicate REPOSITORY_ROOT.join(".devcontainer/tailscale-core-status.sh"), :exist?
    assert_not_predicate REPOSITORY_ROOT.join(".devcontainer/tailscale-core-login-environment.sh"), :exist?
  end

  test "the Dev Container loads only the two repository Compose files" do
    devcontainer = `git show :.devcontainer/devcontainer.json`
    tracked_override = `git ls-files -- .devcontainer/compose.override.yml`.strip

    assert_includes devcontainer, "../compose.yaml"
    assert_includes devcontainer, "../compose.custom.yaml"
    assert_not_includes devcontainer, "compose.override.yml"
    assert_empty tracked_override
  end

  test "compose network external flags are booleans rather than interpolated strings" do
    compose_files = ["compose.yaml", "compose.custom.yaml"]

    compose_files.each do |relative_path|
      contents = REPOSITORY_ROOT.join(relative_path).read

      assert_no_match(/^\s*external:\s*["']?\$\{/i, contents, relative_path)
    end
  end

  test "the tunnel connector joins only the Rails frontend network" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")
    connector_networks = connector.fetch("networks")

    assert_includes connector_networks, "frontend",
                    "a service-level networks: list in an overlay replaces the base list rather " \
                    "than merging with it, so removing frontend here silently detaches the " \
                    "connector from the private *.localhost Rails origins"
    assert_equal ["frontend"], connector_networks
    assert_not overlay.fetch("networks", {}).key?("edge-tunnel"),
               "Edge reaches Rails through Workers VPC; the repositories must not share a " \
               "host Podman network"
    assert_not connector.key?("extra_hosts"),
               "the connector reaches Rails over its private Podman network; a host-gateway " \
               "alias unnecessarily expands the origins reachable from the tunnel sidecar"
  end

  test "the tunnel connector can identify the tunnel it is asked to run" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")
    argv = connector.fetch("command").split

    assert_equal "${CLOUDFLARED_TOKEN:?CLOUDFLARED_TOKEN must be set in .env}",
                 connector.fetch("environment").fetch("TUNNEL_TOKEN")
    assert_equal "run", argv.last
    assert_includes argv, "run", "the connector must still run a tunnel"
  end

  test "the tunnel connector uses a supported pinned cloudflared release" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")

    assert_equal "docker.io/cloudflare/cloudflared:2026.8.2", connector.fetch("image")
  end

  test "no service restarts without a bound" do
    %w(compose.yaml compose.custom.yaml).each do |relative_path|
      compose = YAML.safe_load_file(REPOSITORY_ROOT.join(relative_path), aliases: true)

      compose.fetch("services", {}).each do |name, service|
        next unless service.is_a?(Hash) && service.key?("restart")

        assert_not_equal "unless-stopped", service.fetch("restart"),
                         "#{relative_path}: #{name} would restart forever with no Podman " \
                         "backoff, turning a startup misconfiguration into a restart storm"
      end
    end
  end

  test "the tunnel connector caps what a crash loop can consume" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")

    %w(cpus mem_limit pids_limit logging).each do |key|
      assert connector.key?(key),
             "cloudflare-tunnel declares no #{key}, so a crash loop is bounded only by the host"
    end

    assert_not connector.key?("profiles"),
               "the always-merged development overlay must start its authenticated connector " \
               "during the standard Dev Container lifecycle"
  end

  test "the tunnel token comes only from the gitignored repository environment file" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.custom.yaml"))
    connector = overlay.fetch("services").fetch("cloudflare-tunnel")
    services = overlay.fetch("services")

    assert system("git", "check-ignore", "--quiet", ".env")
    assert_not connector.key?("volumes")
    assert_not services.key?("cloudflared-login")
    assert_not services.key?("cloudflared-credentials")
    assert_not_includes overlay.fetch("volumes", {}).keys, "cloudflared-credentials"
  end

  test "PostgreSQL health checks authenticate through the runtime writer secret" do
    compose = REPOSITORY_ROOT.join("compose.yaml").read

    assert_operator compose.scan('export PGPASSWORD="$$(cat "$${POSTGRES_PASSWORD_FILE}")"').length,
                    :>=,
                    2
  end

  test "every mounted Compose secret is declared and provisioned by the setup script" do
    compose = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.yaml"), aliases: true)
    setup = REPOSITORY_ROOT.join("bin/setup-dev-secrets").read
    declared = compose.fetch("secrets").keys

    compose.fetch("services").each do |name, service|
      next unless service.is_a?(Hash)

      Array(service["secrets"]).each do |secret|
        assert_includes declared, secret, "service #{name} mounts an undeclared secret"
      end
    end

    declared.each do |secret|
      assert_includes setup, "[#{secret}]=", "bin/setup-dev-secrets does not provision #{secret}"
    end
  end

  # --- Remote access: Codex App -> tailnet TCP/22 -> tailscale sidecar -> core sshd ---
  #
  # The sidecar exists because Tailscale inside `core` needed a root PID 1, which
  # `userns_mode: keep-id` and the absent `user:` key rule out. These tests hold that
  # boundary: the daemon stays in its own container, on its own network, with no
  # privilege of any kind, and SSH terminates inside `core`.
  #
  # The whole arrangement now lives in `compose.remote-access.yaml`, a file nothing
  # loads implicitly, and is deliberately identical to the one in
  # umaxica-apps-edge and portal apart from the account name, the tailnet hostname,
  # and core's network list. An assertion that fails here almost certainly needs the
  # same fix in the other two repositories.

  REMOTE_ACCESS_OVERLAY = "compose.remote-access.yaml"
  SSHD_CONFIG_PATH = ".devcontainer/remote-sshd_config"

  test "the Tailscale sidecar needs no privilege, capability, or host access" do
    sidecar = remote_access_sidecar

    assert_equal "true", sidecar.fetch("environment").fetch("TS_USERSPACE"),
                 "userspace networking is what makes every entry below unnecessary; " \
                 "kernel mode would require /dev/net/tun and NET_ADMIN"

    %w(privileged cap_add devices network_mode pid userns_mode).each do |key|
      assert_not sidecar.key?(key),
                 "the sidecar declares #{key}; userspace Tailscale terminates the tailnet " \
                 "connection in netstack and dials core as an ordinary socket, so it needs none"
    end

    assert_equal %w(ALL), sidecar.fetch("cap_drop"),
                 "this is the only container on the host that listens to the tailnet, so it " \
                 "must not be the most permissively configured one"
    assert_includes sidecar.fetch("security_opt"), "no-new-privileges:true"

    assert_not sidecar.key?("ports"),
               "the tailnet is the ingress; a host publication would both defeat the point " \
               "and violate the loopback-only contract in " \
               "docs/operations/development-host-port-exposure.md"
  end

  test "the sidecar image is pinned by digest, not only by tag" do
    assert_match(%r{\Adocker\.io/tailscale/tailscale:v[\d.]+@sha256:\h{64}\z},
                 remote_access_sidecar.fetch("image"),
                 "a mutable tag would let a re-tagged upstream release change the one " \
                 "container here that accepts inbound tailnet connections")
  end

  test "the sidecar exposes no unauthenticated health or metrics endpoint" do
    assert_not remote_access_sidecar.fetch("environment").key?("TS_ENABLE_HEALTH_CHECK"),
               "TS_ENABLE_HEALTH_CHECK opens an unauthenticated /healthz and a metrics " \
               "listener on [::]:9002 reachable by anything on this network, and reports " \
               "nothing `podman logs` does not already say"
  end

  test "the Tailscale sidecar reaches only core, never the data networks" do
    sidecar = remote_access_sidecar

    assert_equal ["remote-access"], sidecar.fetch("networks"),
                 "a tailnet-facing container must not resolve PostgreSQL, Valkey, or Kafka; " \
                 "a service-level networks: list in an overlay replaces rather than merges, " \
                 "so this single entry is the whole reachable set"
    assert_not sidecar.key?("extra_hosts")
  end

  test "the Tailscale sidecar is opt-in and cannot start from a plain compose up" do
    %w(compose.yaml compose.custom.yaml).each do |path|
      services = YAML.safe_load_file(REPOSITORY_ROOT.join(path), aliases: true).fetch("services")

      assert_not services.key?("tailscale"),
                 "#{path} is loaded by a plain `podman compose up` and by devcontainer.json; " \
                 "an inbound network listener must never start from either"
    end

    assert_not_includes REPOSITORY_ROOT.join(".devcontainer/devcontainer.json").read,
                        REMOTE_ACCESS_OVERLAY,
                        "the overlay is added with an explicit -f, never opened by default"
  end

  test "the Tailscale sidecar caps what a crash loop can consume" do
    sidecar = remote_access_sidecar

    %w(cpus mem_limit pids_limit logging).each do |key|
      assert sidecar.key?(key),
             "the sidecar declares no #{key}, so a crash loop is bounded only by the host"
    end
    assert_equal "on-failure:3", sidecar.fetch("restart"),
                 "Podman applies no backoff to unless-stopped, so a misconfiguration would " \
                 "become a restart storm"
  end

  test "the Tailscale auth key is a bootstrap-only interpolation, never a committed value" do
    sidecar = remote_access_sidecar
    environment = sidecar.fetch("environment")

    assert_equal "${TS_AUTHKEY:-}", environment.fetch("TS_AUTHKEY"),
                 "the auth key is revoked after first registration, so it must be absent-able"
    assert_equal "true", environment.fetch("TS_AUTH_ONCE"),
                 "the image default is false, which re-runs `tailscale up` with the key on " \
                 "every start and breaks restart-without-a-key"
    assert_no_match(/tskey-/, REPOSITORY_ROOT.join(REMOTE_ACCESS_OVERLAY).read)
    assert system("git", "check-ignore", "--quiet", ".env")
  end

  test "the preflight refuses to start once a spent auth key is left behind" do
    preflight = REPOSITORY_ROOT.join(".devcontainer/remote-access-preflight.sh")

    assert_predicate preflight, :executable?
    contents = preflight.read

    assert_includes contents, "podman volume exists",
                    "the state volume is the only reliable signal that this node is already " \
                    "enrolled, and therefore that a key still in .env has no purpose left"
    assert_includes contents, "already enrolled",
                    "leaving a single-use key in a file after enrolment is the exact thing " \
                    "the one-off key procedure exists to avoid, so it must fail closed " \
                    "rather than be a sentence in a document"
  end

  test "the sidecar forwards only TCP, and only to core's unprivileged sshd" do
    serve = JSON.parse(REPOSITORY_ROOT.join(".devcontainer/tailscale-serve.json").read)

    assert_equal %w(TCP), serve.keys,
                 "a Web or AllowFunnel section would publish this node beyond the tailnet"
    assert_equal(
      { "TCPForward" => "core:2222" }, serve.fetch("TCP").fetch("22"),
      "tailnet 22 is the only exposed port, and TerminateTLS must stay absent " \
      "because SSH clients cannot speak TLS-terminated TCP",
    )
    assert_equal 1, serve.fetch("TCP").size
  end

  test "core's sshd accepts public keys only and never root" do
    {
      "PasswordAuthentication no" => "passwords must never be an option on a tailnet listener",
      "PermitRootLogin no" => "there is no root in core, and no rule may imply one",
      "AuthenticationMethods publickey" => "public key is the only accepted method",
      "AllowUsers global" => "one user, the keep-id-mapped workload user",
      "StrictModes yes" => "reject a world-writable authorized_keys instead of trusting it",
      "AllowAgentForwarding no" => "no agent socket travels into the development container",
      "MaxAuthTries 3" => "the tailnet is not a single trusted host",
      "LoginGraceTime 20" => "an unauthenticated connection must not be able to linger",
      "Port 2222" => "sshd runs unprivileged and cannot bind 22; the sidecar bridges the two",
    }.each do |directive, reason|
      assert_includes sshd_config, directive, reason
    end
  end

  test "core's sshd forwards ports for previews without becoming a pivot" do
    assert_includes sshd_config, "AllowTcpForwarding yes",
                    "Codex App and VS Code Remote SSH forward dev-server ports over the " \
                    "session; without this no Rails preview is reachable remotely"
    assert_includes sshd_config, "PermitOpen localhost:* 127.0.0.1:* [::1]:*",
                    "an unrestricted forward would reach PostgreSQL, Valkey and Kafka on " \
                    "core's own Podman networks, which is precisely what the sidecar's " \
                    "single-network attachment exists to prevent"
  end

  test "core's sshd keeps its private state off the workspace bind" do
    assert_no_match(%r{^(?:HostKey|PidFile|AuthorizedKeysFile) .*/workspace/}, sshd_config,
                    "the workspace is a bind mount owned by `global`; a host key or PID file " \
                    "there is writable by anything holding a development shell")
    assert_includes sshd_config, "HostKey /home/global/.local/state/remote-sshd/"
    assert_includes sshd_config, "PidFile /home/global/.local/state/remote-sshd/"
  end

  test "core's sshd serves the SFTP subsystem Remote SSH clients edit files over" do
    assert_includes sshd_config, "Subsystem sftp internal-sftp",
                    "without it the connection succeeds and file editing silently does not"
  end

  test "core's sshd carries its whole session environment on one SetEnv line" do
    lines = sshd_config.lines.select { |line| line.start_with?("SetEnv ") }

    assert_equal 1, lines.length,
                 "sshd_config keeps the FIRST value it sees for a keyword and discards the " \
                 "rest, so a second SetEnv line parses cleanly and is silently ignored -- the " \
                 "session then gets the PATH and none of the rest, which reads as a broken " \
                 "toolchain rather than as dropped configuration. This was a real defect here."

    %w(PATH= GEM_HOME= BUNDLE_PATH= BASH_ENV=).each do |name|
      assert_includes lines.first, name, "SetEnv lacks #{name}"
    end
  end

  test "an SSH session receives the service environment Compose sets on core" do
    wrapper = REPOSITORY_ROOT.join(".devcontainer/remote-sshd-entrypoint.sh").read

    assert_includes wrapper, "/proc/self/environ",
                    "sshd builds each session environment from scratch, so without a snapshot " \
                    "of the container's own environment an SSH login sees none of the ~50 " \
                    "database, host-table and OTEL variables compose.yaml sets -- and " \
                    "`bin/rails` fails over SSH while working under `podman exec`"
    assert_includes wrapper, "session-env.sh"
    assert_match(/PREPEND/, wrapper,
                 "Debian's stock ~/.bashrc returns early when non-interactive, so a line " \
                 "appended to it is unreachable for `ssh host cmd` -- the shape every " \
                 "Remote-SSH agent uses")
  end

  test "the docker and podman control-plane trees stay byte-identical" do
    %w(core/entrypoint.sh).each do |relative_path|
      assert_equal REPOSITORY_ROOT.join("podman", relative_path).read,
                   REPOSITORY_ROOT.join("docker", relative_path).read,
                   "docker/#{relative_path} drifted from the podman/ copy the image is built from"
    end
  end

  test "core keeps every base network when the overlay adds remote access" do
    base = YAML.safe_load_file(REPOSITORY_ROOT.join("compose.yaml"), aliases: true)
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join(REMOTE_ACCESS_OVERLAY))
    overlay_networks = overlay.fetch("services").fetch("core").fetch("networks")

    base.fetch("services").fetch("core").fetch("networks").each_key do |name|
      assert_includes overlay_networks, name,
                      "a service-level networks: key in an overlay REPLACES the base list, so " \
                      "dropping #{name} here would silently detach core from it -- and with " \
                      "frontend, from every Cloudflare Tunnel ingress rule"
    end
    assert_includes overlay_networks, "remote-access"
  end

  test "core's sshd closes every forwarding channel it does not need" do
    {
      "PubkeyAuthentication yes" => "the only method AuthenticationMethods leaves available",
      "KbdInteractiveAuthentication no" => "the second interactive path a password rule misses",
      "UsePAM no" => "opening a PAM session needs root, which this sshd does not have",
      "AllowStreamLocalForwarding no" => "a unix-socket forward reaches the same services a " \
                                         "TCP forward would",
      "X11Forwarding no" => "the Codex App needs a shell, not a display",
      "PermitTunnel no" => "a tun device would put the client on core's Podman networks",
      "GatewayPorts no" => "a remote forward must not become reachable beyond core",
      "PermitUserEnvironment no" => "an authorized_keys environment= would survive as config",
    }.each do |directive, reason|
      assert_includes sshd_config, directive, reason
    end
  end

  test "remote access starts sshd as core's own process rather than a background fork" do
    core = YAML.safe_load_file(REPOSITORY_ROOT.join(REMOTE_ACCESS_OVERLAY))
      .fetch("services").fetch("core")

    assert_equal "/usr/local/bin/remote-sshd-entrypoint", core.fetch("command"),
                 "sshd in the foreground is what makes the restart policy and `podman logs` " \
                 "see the real process; the previous REMOTE_SSHD=1 fork left a server whose " \
                 "death was invisible until the next connection attempt"

    assert_no_match(/REMOTE_SSHD/, REPOSITORY_ROOT.join("podman/core/entrypoint.sh").read,
                    "the entrypoint no longer knows about remote access at all")
  end

  test "the Codex public key is a read-only mount from the gitignored secrets directory" do
    core = YAML.safe_load_file(REPOSITORY_ROOT.join(REMOTE_ACCESS_OVERLAY))
      .fetch("services").fetch("core")
    mount =
      core.fetch("volumes").find do |entry|
        entry.is_a?(Hash) && entry.fetch("target", "").end_with?("authorized_keys")
      end

    assert mount, "core mounts no authorized_keys, so sshd could authenticate nobody"
    assert_equal "./.secrets/codex_authorized_keys", mount.fetch("source"),
                 ".secrets/ is gitignored and excluded from both build contexts, so the key " \
                 "never enters an image layer -- and unlike the host's own " \
                 "~/.ssh/authorized_keys it admits one key rather than every key that can " \
                 "log into the host"
    assert mount.fetch("read_only"),
           "a writable authorized_keys would let a development shell grant itself new access"
    assert_includes REPOSITORY_ROOT.join("bin/setup-dev-secrets").read, "codex_authorized_keys",
                    "Podman invents a DIRECTORY when a bind source is missing and every `up` " \
                    "then fails, so the setup script must create the file even when unused"
  end

  test "the tailnet node identity and sshd host key outlive their containers" do
    overlay = YAML.safe_load_file(REPOSITORY_ROOT.join(REMOTE_ACCESS_OVERLAY))
    volumes = overlay.fetch("volumes")

    assert_includes volumes.keys, "tailscale-state",
                    "without persisted state every restart registers a NEW node and the " \
                    "tailnet name drifts to umaxica-global-core-1, -2, ..."
    assert_equal "/var/lib/tailscale",
                 remote_access_sidecar.fetch("environment").fetch("TS_STATE_DIR")
    assert_includes volumes.keys, "sshd-host-keys",
                    "a regenerated host key makes the client's known_hosts entry fail closed " \
                    "on every container recreation"
  end

  test "RustFS credentials are mounted secrets rather than Compose interpolation" do
    compose = REPOSITORY_ROOT.join("compose.yaml").read

    assert_includes compose, "OBJECT_STORAGE_ACCESS_KEY_ID_FILE: /run/secrets/dev_rustfs_access_key"
    assert_includes compose, "OBJECT_STORAGE_SECRET_ACCESS_KEY_FILE: /run/secrets/dev_rustfs_secret_key"
    assert_no_match(
      /^\s*(?:OBJECT_STORAGE_(?:ACCESS_KEY_ID|SECRET_ACCESS_KEY)|RUSTFS_(?:ACCESS_KEY|SECRET_KEY|RPC_SECRET)):\s*["']?\$\{/,
      compose,
      "object-storage credentials must not come from .env interpolation",
    )
  end

  private

  def remote_access_sidecar
    YAML.safe_load_file(REPOSITORY_ROOT.join(REMOTE_ACCESS_OVERLAY))
      .fetch("services")
      .fetch("tailscale")
  end

  # Comments are stripped: the file explains at length why several directives are
  # set the way they are, and prose must not be able to satisfy an assertion.
  def sshd_config
    @sshd_config ||= REPOSITORY_ROOT.join(SSHD_CONFIG_PATH)
      .read
      .lines
      .reject { |line| line.lstrip.start_with?("#") }
      .join
  end
end
