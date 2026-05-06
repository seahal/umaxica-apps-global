# Dev Container Usage

## VS Code

- Install the Dev Containers extension.
- Open the repository folder and run **Reopen in Container**.
- The container runs `bundle install` and `pnpm install`; wait for the
  `Development environment ready!` message before starting tasks.

## IntelliJ IDEA (Gateway)

- Install JetBrains Gateway and choose **Dev Containers** as the connection method.
- Select the `umaxica-apps-jit` container definition; Gateway downloads the IntelliJ backend with
  the Ruby plugin pre-configured.
- When the IDE connects, run `bin/rails db:prepare` if database setup did not finish automatically.

### Notes

- Port `63342` is published for JetBrains backend services if you need manual forwarding.
- The container includes additional desktop libraries required by IntelliJ backend builds.
