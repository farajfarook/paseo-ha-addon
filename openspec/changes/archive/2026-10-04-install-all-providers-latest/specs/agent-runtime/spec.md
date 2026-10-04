# Spec Delta

## REMOVED Requirements

### Requirement: Bundled Pi harness
**Reason**: Already superseded by `agent-providers`; this change also takes Pi out of the image. Pi is installed on start at its latest stable release like every other provider (see `agent-providers`: "Installed CLIs follow the selection" and "Latest stable versions").
**Migration**: None needed. Pi stays selected by default and is installed on the first start after the update. Pi's logins, settings and packages under `/data/home/.pi` are kept, so authentication still persists across restarts and updates.
