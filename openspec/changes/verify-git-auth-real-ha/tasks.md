## 1. Real-HA verification

- [ ] 1.1 On a real HA instance (amd64 and aarch64): run `gh auth login` in a Paseo terminal, restart and update the add-on, and confirm `gh auth status`. Ask a Pi agent to clone a private GitHub repo over HTTPS and open a draft PR. Place a deploy key in `/homeassistant/.ssh` with mode 644 via Samba and confirm an agent clones over SSH without prompts. Verify that the start log shows both and contains no secrets (carried over from `add-git-auth` task 4.2)
