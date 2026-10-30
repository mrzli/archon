# Secret scan on push

Every `git push` scans the commits being pushed with
[gitleaks](https://github.com/gitleaks/gitleaks) and blocks the push when it
finds something that looks like a secret, such as an API key, a token, or a
private key. gitleaks runs locally and sends nothing anywhere.

The scan is a configured hook in `~/.config/git/config` (`hook.gitleaks`), so
it runs in every repository, before the repository's own `pre-push` hook. It
scans only the commits that the remote's branches did not hold at the last
fetch, which may include a few more than the push sends. Setup installs
gitleaks; without it, every push is blocked.

When a push is blocked:

- For a real secret, remove it from the commits, such as by amending or
  rebasing, and revoke it if it was ever shared.
- For a false positive, add the fingerprint that gitleaks prints to the
  repository's `.gitleaksignore`, or adjust its rules in `.gitleaks.toml`.
- To push once without the scan, run `git push --no-verify`. This also skips
  the repository's own `pre-push` hook.

To turn the scan off for one repository, run
`git config hook.gitleaks.enabled false` in it.
