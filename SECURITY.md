# Security policy

Tempa is a control plane for coding agents: it brings your company's standards, guardrails and shared context
into every developer's coding harness. This repository holds its plugin and the `tempa` CLI it carries. We take
reports about the plugin, the CLI and the Tempa service seriously.

## Reporting a vulnerability

Report it privately, never in a public issue, pull request or chat.

- **Where**: the contact in [`https://tempa.devleaps.nl/.well-known/security.txt`](https://tempa.devleaps.nl/.well-known/security.txt)
  (RFC 9116).
  <!-- TODO(human): name the security contact here (the value of TEMPA_WEB_SECURITY_CONTACT once a person has
  decided it), and make sure security.txt answers, before this repository goes public. -->
- **What to send**: what you found, the steps to reproduce, the version (`tempa --version`, or `version` in the
  plugin's manifest), the impact you expect, and how to reach you.
- **Please do not** access, change or keep data that is not yours, degrade the service, or test beyond what your
  own account may do. Stop at the proof and tell us.

## What happens next

| When            | What                                                              |
| --------------- | ----------------------------------------------------------------- |
| 3 working days  | We confirm we received it                                         |
| 10 working days | Our first assessment and severity                                 |
| 90 days         | Target to fix and disclose together; sooner for critical findings |

We credit reporters who want to be credited once the fix is out, and we do not take legal action against
good-faith research that follows this policy.

## Supported versions

Only the latest release in this repository receives security fixes. Update with your harness's plugin update
command (see the README).

## Scope

In scope: the plugin and the `tempa` CLI in this repository, and the Tempa service at `tempa.devleaps.nl`. Out of
scope: the coding harness itself and other third-party services, volumetric denial of service, and bypassing
Tempa's guardrails on your own laptop (they run on the client by design).
