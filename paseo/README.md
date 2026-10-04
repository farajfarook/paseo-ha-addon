# Home Assistant Add-on: Paseo

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

Configure Home Assistant with coding agents. [Paseo](https://paseo.sh) runs Pi
(the default), Claude, Codex, Copilot, OpenCode and Oh My Pi, chosen in one option and kept at their latest stable release, behind a daemon with a web UI, opened
from the Home Assistant sidebar and authenticated by Home Assistant.

- Opens as **Paseo** in the sidebar via Ingress — no ports, tokens or pairing.
- Agents start in `/homeassistant` with live Core API, `ha` CLI and optional HA MCP access.
- Bundled Home Assistant guidance with a safe edit → check → reload → verify workflow.
- Optional git snapshots of your configuration for easy rollback.

See the **Documentation** tab for setup, options and the security model.

## Attribution

Paseo is © the Paseo authors and licensed under the
[Apache License 2.0](https://github.com/getpaseo/paseo/blob/main/LICENSE).
`icon.png` and `logo.png` are rendered from Paseo's
[`packages/website/public/logo.svg`](https://github.com/getpaseo/paseo/blob/main/packages/website/public/logo.svg)
under that license. This add-on is not affiliated with or endorsed by the Paseo project.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
