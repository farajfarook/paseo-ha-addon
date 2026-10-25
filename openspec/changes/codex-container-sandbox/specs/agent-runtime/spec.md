## ADDED Requirements

### Requirement: Codex process management dependencies
The runtime image SHALL provide a procps-compatible ps executable.

#### Scenario: Shared app-server startup
- **WHEN** Codex identifies its PID-managed app-server
- **THEN** `ps -p <pid> -o stat= -o lstart=` succeeds for a live process

### Requirement: Confined Codex namespace setup
The add-on SHALL use an enforcing AppArmor profile that permits Codex Bubblewrap
namespace setup without granting CAP_SYS_ADMIN in the initial user namespace.

#### Scenario: Workspace execution
- **WHEN** Codex runs a shell command with workspace-write permissions
- **THEN** it can modify authorized workspace files while writes outside the
  authorized roots remain denied

#### Scenario: Other processes
- **WHEN** a process outside the Codex child profile attempts namespace mounts
- **THEN** AppArmor denies mount operations
