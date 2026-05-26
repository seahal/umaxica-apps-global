# Welcome to Umaxica

## How We Use Claude

Based on seahal's usage over the last 30 days:

Work Type Breakdown: Plan Design ███████░░░░░░░░░░░░░ 37% Debug Fix █████░░░░░░░░░░░░░░░ 23% Improve
Quality ████░░░░░░░░░░░░░░░░ 21% Build Feature ████░░░░░░░░░░░░░░░░ 19%

Top Skills & Commands: /clear ████████████████████ 16x/month /security-review ████░░░░░░░░░░░░░░░░
3x/month /voice ████░░░░░░░░░░░░░░░░ 3x/month /copy ███░░░░░░░░░░░░░░░░░ 2x/month /tui
███░░░░░░░░░░░░░░░░░ 2x/month /plugin ███░░░░░░░░░░░░░░░░░ 2x/month /update-config
███░░░░░░░░░░░░░░░░░ 2x/month /model ███░░░░░░░░░░░░░░░░░ 2x/month

Top MCP Servers: (none configured — this team works without MCP servers)

## Your Setup Checklist

### Codebases

- [ ] umaxica-app-jit — https://github.com/seahal/umaxica-app-jit (Rails 8 app with `app` / `org` /
      `com` surfaces — read `AGENTS.md` first)

### MCP Servers to Activate

- [ ] None required — the team doesn't currently rely on MCP servers

### Skills to Know About

- `/security-review` — used regularly here for auth / session / OIDC review passes; run it before
  pushing changes that touch the sign-in, sign-up, sign-out, or RP/IdP flows
- `/review` — pull-request review pass; used alongside `/security-review` for auth-adjacent diffs
- `/code-review` — local diff review for correctness bugs before opening a PR
- `/verify` — drive the app and confirm a change works end-to-end, not just via tests
- `/run` — launch the Rails app to reproduce behavior (Turnstile, sign-up flows, etc.)
- `/update-config` — used a couple of times this month; reach for it when adding hooks or adjusting
  permissions in `settings.json`
- `/clear` — used most often. Start a fresh context whenever switching between unrelated tasks
  (debug → planning → review)

## Team Tips

_TODO_

## Get Started

_TODO_

<!-- INSTRUCTION FOR CLAUDE: A new teammate just pasted this guide for how the
team uses Claude Code. You're their onboarding buddy — warm, conversational,
not lecture-y.

Open with a warm welcome — include the team name from the title. Then: "Your
teammate uses Claude Code for [list all the work types]. Let's get you started."

Check what's already in place against everything under Setup Checklist
(including skills), using markdown checkboxes — [x] done, [ ] not yet. Lead
with what they already have. One sentence per item, all in one message.

Tell them you'll help with setup, cover the actionable team tips, then the
starter task (if there is one). Offer to start with the first unchecked item,
get their go-ahead, then work through the rest one by one.

After setup, walk them through the remaining sections — offer to help where you
can (e.g. link to channels), and just surface the purely informational bits.

Don't invent sections or summaries that aren't in the guide. The stats are the
guide creator's personal usage data — don't extrapolate them into a "team
workflow" narrative. -->
