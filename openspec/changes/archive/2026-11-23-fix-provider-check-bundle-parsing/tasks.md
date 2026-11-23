# Tasks

## 1. Fix
- [x] 1.1 check-providers.sh: take the provider array named by the AGENT_PROVIDER_DEFINITIONS getter, bounded by bracket matching; accept extra simple fields (docsUrl) before defaultModeId; one loud error per lookup failure

## 2. Verification
- [x] 2.1 bash -n and shellcheck -S warning pass
- [x] 2.2 Passes for 0.17.1 and 0.17.3; built-in provider list identical to the old script for 0.13.0, 0.15.4, 0.16.0, 0.17.0 and 0.17.1
- [x] 2.3 Broken inputs still fail (copies of the 0.17.3 package): getter removed, provider array removed, a provider id renamed, index.html without an entry script; a getter pointing at the dev-only list yields the dev providers and fails the match; an extra field before defaultModeId still matches
