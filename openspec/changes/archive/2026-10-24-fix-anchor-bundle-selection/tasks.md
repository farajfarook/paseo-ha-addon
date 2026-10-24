# Tasks

## 1. Fix
- [x] 1.1 paseo-anchors.sh: read the entry bundle named in web-ui/index.html; separate loud errors for a missing entry bundle and a missing protocol daemon-endpoints.js
- [x] 1.2 check-providers.sh: read the entry bundle named in web-ui/index.html; loud error when index.html names none or the file is missing

## 2. Verification
- [x] 2.1 bash -n and shellcheck -S warning pass for both scripts
- [x] 2.2 paseo-anchors.sh --check and check-providers.sh pass for both 0.12.0 and 0.13.0
- [x] 2.3 Broken inputs still fail (on copies of the 0.13.0 package): an anchor string removed from the entry bundle counts 0; AGENT_PROVIDER_DEFINITIONS removed from the entry bundle fails check-providers.sh; index.html without an entry script and an entry script that does not exist fail both scripts
