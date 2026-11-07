# Tempa for GitHub Copilot

[Tempa](https://tempa.devleaps.nl) brings your company's engineering standards, skills, guardrails and shared
context into every GitHub Copilot session, in the Copilot CLI and in VS Code, from one control plane. Your company
configures it once; on your laptop the plugin keeps each repo's setup in place and checks risky tool calls. Your
coding traffic stays in your own Copilot plan: Tempa configures the harness, it does not proxy the model.

You need an account on a Tempa tenant: your company's subscription, or a tenant Devleaps set up for you.

## Install

You need the Copilot CLI 1.0 or newer (`copilot --version`; `copilot update` updates it) and Node.js 20 or newer
(`node --version`). The plugin carries the `tempa` CLI, so there is nothing else to install. One install serves the
Copilot CLI and VS Code.

```sh
copilot plugin marketplace add Devleaps/tempa-copilot
copilot plugin install tempa@devleaps
```

In VS Code, switch on `"chat.plugins.enabled": true` in your user settings; VS Code picks up the plugin the Copilot
CLI installed.

## Log in

Copilot has no `/tempa:` commands, so log in once from a terminal:

```sh
~/.copilot/installed-plugins/devleaps/tempa/bin/tempa-launch login
```

It shows a URL and a code, and your browser opens on Tempa's device page. Sign in the way your company set up:
with your work account (Microsoft, Google or GitHub), or with a sign-in link Tempa sends to your e-mail address.
Confirm the code, and you are done. Start `copilot` in a repo: the session start puts the repo's profile in place,
and every tool call goes through Tempa's guardrails.

For `tempa` in your terminal, copy the wrapper once:
`install -m 755 ~/.copilot/installed-plugins/devleaps/tempa/scripts/tempa ~/.local/bin/tempa`.

## What the plugin does on your machine

- **Hooks.** The plugin hooks `sessionStart`, `userPromptSubmitted`, `preToolUse`, `postToolUse`, `agentStop` and
  `sessionEnd`. Each runs the `tempa` CLI it carries, with Node.js, on your machine: the session start syncs your
  profile from your company's Tempa tenant, and every tool call is checked against your company's policies (allow,
  ask or deny). The hooks fail closed: when Tempa cannot run (no Node.js 20, a damaged plugin), tool calls are
  denied with a one-line fix instead of running unchecked. Copilot itself lets a call through when a hook times
  out.
- **MCP server.** The plugin adds a `tempa` MCP server (the same CLI), which gives Copilot your company's shared
  context and tools from your tenant.
- **Files in your repositories.** In a git repository, Tempa writes your profile's standards, skills and agents
  into `.github/instructions/`, `.github/skills/` and `.github/agents/` (as `tempa-*`), and lists every path it
  writes in `.git/info/exclude`, so nothing reaches your commits. It never edits `.gitignore` or a file git tracks.
- **Settings.** When your company's profile turns telemetry on, Tempa adds `telemetry.headersProvider` to
  `~/.copilot/settings.json` (your other settings stay) and writes a shell wrapper, `~/.tempa/copilot-otel.sh`,
  that you load from your shell profile yourself: Tempa never edits a shell profile. Each sync also adds Tempa's
  OpenTelemetry settings for Claude Code (an `env` block of `OTEL_*` variables and `otelHeadersHelper`) to
  `~/.claude/settings.json`, after saving that file once as `~/.claude/settings.json.tempa-backup`; `tempa logout`
  removes exactly those keys.
- **Telemetry.** With telemetry on and the wrapper loaded, Copilot's own spans and metrics (sessions, model calls,
  token counts, tool calls) and Tempa's events (profile syncs, and each tool-call decision with the tool's name and
  the policy that decided) go to your company's Tempa tenant. Prompts, responses, tool arguments and tool output
  are not kept unless your company turns content capture on, and identifiers such as your e-mail address are
  pseudonymised on arrival.
- **Your home folder.** `~/.tempa` holds your login, the cached profiles and the launcher's path.

More in the documentation: https://tempa.devleaps.nl/docs

## Updates

Each Tempa release updates this repository:

```sh
copilot plugin marketplace update devleaps && copilot plugin update tempa@devleaps
```

## More

- Something wrong? Run `tempa doctor` (without the wrapper:
  `~/.copilot/installed-plugins/devleaps/tempa/bin/tempa-launch doctor`): every failed check comes with a
  one-line fix.
- The full guide, with Claude Code and other harnesses, telemetry and locking Copilot down for an organisation:
  https://tempa.devleaps.nl/docs/install#github-copilot
- Remove Tempa, while the plugin is still there: `tempa clean --all` takes back what Tempa wrote into your
  repositories (the `tempa-*` files under `.github/` and the `# >>> tempa:copilot` block in `.git/info/exclude`)
  and the `~/.claude/settings.json.tempa-backup` it made; files you changed are kept and listed, and `--dry-run`
  shows what it would do. Then `tempa logout` (without the wrapper:
  `~/.copilot/installed-plugins/devleaps/tempa/bin/tempa-launch clean --all`, then `…/bin/tempa-launch logout`). Then
  `copilot plugin uninstall tempa@devleaps`, delete `~/.tempa`, and take `telemetry.headersProvider` out of
  `~/.copilot/settings.json` and the `copilot-otel.sh` line out of your shell profile.

## Support, security and licence

- Questions and support: https://tempa.devleaps.nl/contact, or your company's Tempa administrator.
- Found a vulnerability? See [SECURITY.md](SECURITY.md); please do not open a public issue.
- The plugin and the CLI are proprietary: you may use them with a Tempa subscription or a tenant provided by
  Devleaps, and not modify or redistribute them. See [LICENSE](LICENSE).
- The CLI contains open source components under their own licences, which the Tempa licence does not cover: see
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

This repository is release output, built from Tempa's own source on every release. Pull requests and issues are
not accepted here.
