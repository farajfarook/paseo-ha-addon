# Security policy

## Supported versions

Only the latest release of the add-on is supported. Releases are
`<paseo>-<rev>`; update to the newest one before reporting.

## Reporting a vulnerability

Please do **not** open a public issue for security problems.

Use GitHub's private reporting: **Security → Report a vulnerability** on
<https://github.com/farajfarook/paseo-ha-addon/security/advisories/new>.
You will get an acknowledgement within 7 days.

In scope for this repository:

- The ingress adapter (nginx config, `shim.js`, `render.js`) - for example an
  authentication bypass, a way to reach the daemon without the Home Assistant
  session, or token leakage.
- The init scripts under `paseo/rootfs/etc/paseo-ha/init.d/` - for example
  secrets written to logs or to `/homeassistant`, or the direct port opening
  without a password.
- The bundled agent guidance and MCP wiring, where it causes credentials to be
  exposed.

Out of scope here, report upstream instead:

- Paseo itself: <https://github.com/getpaseo/paseo/security>.
- The agent CLIs (Claude Code, Codex, Copilot, OpenCode, Pi, Oh My Pi, Muse
  Code, Antigravity) and their vendors.
- Home Assistant Supervisor / Core.

## Threat model

Read [Security and trust model](paseo/DOCS.md#security-and-trust-model) first.
By design, agents run as root inside the container with read-write access to
the Home Assistant configuration and a Supervisor `manager` token, and anyone
who can open the sidebar panel can drive them. Those are documented properties
of the add-on, not vulnerabilities. Prompt injection through files an agent
reads is a known risk; the mitigations are documented in the same section.
