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
- Remove Tempa: `tempa logout`, then `copilot plugin uninstall tempa@devleaps`, and delete `~/.tempa`.

## Support, security and licence

- Questions and support: https://tempa.devleaps.nl/contact, or your company's Tempa administrator.
- Found a vulnerability? See [SECURITY.md](SECURITY.md); please do not open a public issue.
- The plugin and the CLI are proprietary: you may use them with a Tempa subscription or a tenant provided by
  Devleaps, and not modify or redistribute them. See [LICENSE](LICENSE).

This repository is release output, built from Tempa's own source on every release. Pull requests and issues are
not accepted here.
