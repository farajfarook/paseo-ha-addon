## Why

The README had no screenshot or recording, so nobody discovering the repository could see what the add-on does. A demo now exists (desktop flow and phone).

## What Changes

- `docs/demo.gif` (4.4 MB, 960 px, 10 fps): sidebar → new workspace → agent adds an automation, config check, reload, verify, git commit → diff → the automation in Settings → the same session on a phone.
- Root `README.md`: embeds the GIF as the hero and links the YouTube version (https://youtu.be/jiKUqDyML24).
- `AGENTS.md` Rule 1: `docs/**` added to the OpenSpec-exempt list for README media. Takes effect after merge; this change is the OpenSpec record for the file it adds.

No file under `paseo/` changes, so nothing ships and there is no version bump.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None (repository documentation only).

## Impact

- `docs/demo.gif`, `README.md`, `AGENTS.md`.
