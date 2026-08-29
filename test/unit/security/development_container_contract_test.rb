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

  test "the development container bakes one pinned Tailscale and no supervisor scripts" do
    containerfile = REPOSITORY_ROOT.join("Containerfile").read

    assert_match(/tailscale=\d+\.\d+\.\d+/, containerfile,
                 "`core` joins the tailnet itself now, so the client is an image dependency " \
                 "and must be version-pinned the way the sidecar image's digest used to be")
    assert_includes containerfile, "pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg",
                    "the apt repository must be signed by Tailscale's own key, not trusted"
    assert_includes containerfile,
                    "COPY --chown=0:0 .devcontainer/tailscale-wrapper.sh /usr/local/bin/tailscale",
                    "the bare CLI dials a root tailscaled this container cannot run; the " \
                    "wrapper is what makes `tailscale up` work in a development shell"

    assert_not_includes REPOSITORY_ROOT.join(".devcontainer/devcontainer.json").read, "tailscale",
                        "joining the tailnet stays opt-in; devcontainer.json must not arrange it"

    # The supervisor/status/login-environment trio was the earlier in-container
    # attempt, which ran tailscaled from shell hooks nothing owned. Userspace mode
    # under the sshd entrypoint replaced it; reintroducing any of them would mean
    # two things start the same daemon on the same socket.
    %w(
      .devcontainer/tailscale-core-supervisor.sh
      .devcontainer/tailscale-core-status.sh
      .devcontainer/tailscale-core-login-environment.sh
      .devcontainer/tailscale-serve.json
    ).each do |path|
      assert_not_predicate REPOSITORY_ROOT.join(path), :exist?
    end
  end

  test "the Tailscale wrapper starts a user-space daemon and never asks for privilege" do
    wrapper = REPOSITORY_ROOT.join(".devcontainer/tailscale-wrapper.sh")

    assert_predicate wrapper, :executable?
    contents = wrapper.read
    # Comments are stripped: the file explains at length why root is unavailable
    # here, and prose must not be able to satisfy -- or break -- an assertion.
    code = contents.lines.reject { |line| line.lstrip.start_with?("#") }.join

    assert_includes contents, "--tun=userspace-networking",
                    "kernel mode would need /dev/net/tun and NET_ADMIN, which is exactly the " \
                    "privilege the sidecar was built to avoid requesting"
    assert_no_match(/\bsudo\b|\bsu -/, code,
                    "there is no sudo in this image and no root to escalate to")
    assert_includes contents, "exec /usr/bin/tailscale",
                    "beyond starting the daemon the wrapper must be a pass-through, or the " \
                    "CLI's own behaviour becomes this repository's to maintain"
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

  # --- Remote access: Codex App -> tailnet TCP/22 -> tailscaled in core -> core sshd ---
  #
  # There is no sidecar. Tailscale ran in its own container while the belief held
  # that tailscaled needs a root PID 1, which `userns_mode: keep-id` and the absent
  # `user:` key rule out. Userspace networking needs neither, so the daemon moved
  # into `core`: the same no-privilege posture, one less container, and no
  # `remote-access` bridge whose service-level `networks:` list had to restate
  # every network `core` already had.
  #
  # The whole arrangement lives in `compose.remote-access.yaml`, a file nothing
  # loads implicitly, and is deliberately identical to the one in
  # umaxica-apps-edge and portal apart from the account name and the tailnet
  # hostname. An assertion that fails here almost certainly needs the same fix in
  # the other two repositories.

  REMOTE_ACCESS_OVERLAY = "compose.remote-access.yaml"
  SSHD_CONFIG_PATH = ".devcontainer/remote-sshd_config"

  test "remote access asks for no privilege, capability, or host access" do
    core = remote_access_core

    assert_includes entrypoint, "--tun=userspace-networking",
                    "userspace networking is what makes every entry below unnecessary; " \
                    "kernel mode would require /dev/net/tun and NET_ADMIN"

    %w(privileged cap_add devices network_mode pid ports).each do |key|
      assert_not core.key?(key),
                 "the overlay declares #{key}; userspace Tailscale terminates the tailnet " \
                 "connection in netstack and dials sshd over loopback, so it needs none -- " \
                 "and a host publication would violate the loopback-only contract in " \
                 "docs/operations/development-host-port-exposure.md"
    end
  end

  test "no Tailscale sidecar returns, under any compose file" do
    (CONFIGURATION_FILES + [".devcontainer/compose.override.yml"]).each do |path|
      file = REPOSITORY_ROOT.join(path)
      next unless file.exist?

      services = YAML.safe_load_file(file, aliases: true).fetch("services", {})

      assert_not services.key?("tailscale"),
                 "#{path} declares a `tailscale` service; the daemon belongs inside `core`, " \
                 "and a second one would race it for the same node identity"
    end
  end

  test "the tailnet listener is opt-in and cannot start from a plain compose up" do
    %w(compose.yaml compose.custom.yaml).each do |path|
      compose = REPOSITORY_ROOT.join(path).read

      assert_no_match(/remote-sshd-entrypoint/, compose,
                      "#{path} is loaded by a plain `podman compose up` and by " \
                      "devcontainer.json; an inbound network listener must never start " \
                      "from either")
    end

    assert_not_includes REPOSITORY_ROOT.join(".devcontainer/devcontainer.json").read,
                        REMOTE_ACCESS_OVERLAY,
                        "the overlay is added with an explicit -f, never opened by default"
  end

  test "tailscaled is reaped rather than left as a zombie beside sshd" do
    assert remote_access_core.fetch("init", false),
           "the entrypoint backgrounds tailscaled and execs sshd, so without an init the " \
           "daemon's death would be invisible until the next connection attempt"
  end

  test "the Tailscale auth key is a bootstrap-only interpolation, never a committed value" do
    assert_equal "${TS_AUTHKEY:-}", remote_access_core.fetch("environment").fetch("TS_AUTHKEY"),
                 "the auth key is revoked after first registration, so it must be absent-able"
    assert_includes entrypoint, "if [[ -n ${TS_AUTHKEY:-} ]]",
                    "`tailscale up` must run only while enrolling; re-running it with a spent " \
                    "single-use key fails every start after the first"
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

  test "the node forwards only TCP, and only to its own unprivileged sshd" do
    assert_includes entrypoint, "serve --bg --tcp=22 tcp://127.0.0.1:2222",
                    "tailnet 22 is the only exposed port, it reaches sshd over loopback, and " \
                    "a Web or Funnel section would publish this node beyond the tailnet"
    assert_no_match(/funnel/i, entrypoint,
                    "Funnel would put a development container on the public internet")
    assert_no_match(/tailscale.*\bup\b.*--ssh/, entrypoint,
                    "Tailscale SSH would bypass sshd and the authorized-keys contract entirely")
    assert_includes entrypoint, "--accept-dns=false",
                    "accepting tailnet DNS would replace the container's resolver, and with " \
                    "it every compose name core resolves PostgreSQL and Kafka by"
    assert_includes entrypoint, "--advertise-tags=tag:umaxica-devcontainer",
                    "one tag covers all three development containers with a single ACL grant, " \
                    "and tagged nodes are exempt from user key expiry"
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
      "Port 2222" => "sshd runs unprivileged and cannot bind 22; tailscaled bridges the two",
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
                    "core's own Podman networks, which is precisely what this " \
                    "restriction exists to prevent"
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

  test "the overlay leaves core's networks alone" do
    overlay_core = remote_access_core

    assert_not overlay_core.key?("networks"),
               "a service-level networks: key in an overlay REPLACES the base list rather " \
               "than merging, so restating it is how core silently loses frontend -- and " \
               "with it every Cloudflare Tunnel ingress rule. With tailscaled inside core " \
               "there is nothing left for the key to add."
    assert_not YAML.safe_load_file(REPOSITORY_ROOT.join(REMOTE_ACCESS_OVERLAY))
      .key?("networks"),
               "the `remote-access` bridge existed only to carry the sidecar to core"
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

    state_mount =
      remote_access_core.fetch("volumes").find do |entry|
        entry.is_a?(Hash) && entry.fetch("source", nil) == "tailscale-state"
      end

    assert state_mount, "the node identity has nowhere to persist"
    assert_equal "/home/global/.local/state/tailscale", state_mount.fetch("target"),
                 "the daemon runs as `global` and is pointed at this --statedir by the " \
                 "entrypoint; a mismatch persists an empty directory and re-enrols silently"
    assert_includes entrypoint, "ts_state=/home/global/.local/state/tailscale"
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

  def remote_access_core
    @remote_access_core ||= YAML.safe_load_file(REPOSITORY_ROOT.join(REMOTE_ACCESS_OVERLAY))
      .fetch("services")
      .fetch("core")
  end

  def entrypoint
    @entrypoint ||= REPOSITORY_ROOT.join(".devcontainer/remote-sshd-entrypoint.sh").read
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
