from pathlib import Path


SCRIPT = Path("bin/omaux-window-controls").read_text(encoding="utf-8")


def require(fragment: str) -> int:
    position = SCRIPT.find(fragment)
    assert position >= 0, f"missing security invariant: {fragment}"
    return position


sha_guard = require('[[ "$upstream_commit" =~ ^[0-9a-f]{40}$ ]]')
clone = require('git clone --quiet --filter=blob:none --no-checkout "$REPO_URL" "$stage"')
fetch = require('git -C "$stage" fetch --quiet --depth=1 origin "$upstream_commit"')
checkout = require('git -C "$stage" checkout --quiet --detach "$upstream_commit"')
verify = require('[[ "$actual" == "$upstream_commit" ]]')

assert sha_guard < clone < fetch < checkout < verify
print("pinned hyprbars source tests: PASS")
