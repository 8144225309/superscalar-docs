#!/usr/bin/env bash
# lint-docs-drift.sh — flag likely t/1143 design drift in the SuperScalar docs.
#
# The current canonical design is t/1242: pseudo-Spilman leaves (no DW/nSequence
# at the leaf), interior-only Decker-Wattenhofer, L-stock recovery via a
# redistribution TX (not an OP_RETURN burn), and revocation only on the inner
# BOLT-2 channel. This script greps for stale patterns from the older t/1143
# design and reports them for review.
#
# To avoid false-positives on pages that LEGITIMATELY discuss the lineage, a
# matching line is skipped if it also carries a "reconciliation marker"
# (t/1143, replaced, obsolete, former, interior, "not the leaves", legacy, ...).
#
# Usage:  scripts/lint-docs-drift.sh [docs-root]   (default: repo root)
# Exit:   1 if any candidate drift lines remain, else 0. Suitable for CI.
set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

RECON='t/1143|t/1242|1242|delvingbitcoin|https?://|replac|remov|obsolete|former|no longer|\bno\b|\bnot\b|\bnone\b|without|eliminat|free of|\bzero\b|rather than|structural|interior|not the lea|legacy|historical|used to|previously'

# High-signal stale patterns (case-insensitive). Keep these tight to limit noise.
PATTERNS=(
  'state node[s]? at the lea(f|ves)'
  'Decker-Wattenhofer.{0,40}(leaf|leaves)'
  '(leaf|leaves).{0,40}Decker-Wattenhofer'
  'nSequence.{0,25}(leaf|leaves)'
  '(leaf|leaves).{0,25}nSequence'
  'burn.{0,25}(L-stock|liquidity stock)'
  '(L-stock|liquidity stock).{0,25}burn'
  'OP_RETURN.{0,25}(L-stock|burn|liquidity)'
  'per-leaf revocation'
  'revocation.{0,20}(leaf|leaves)'
)

found=0
while IFS= read -r f; do
  for p in "${PATTERNS[@]}"; do
    while IFS=: read -r ln text; do
      [ -z "${ln:-}" ] && continue
      printf '%s' "$text" | grep -qiE "$RECON" && continue
      printf 'DRIFT? %s:%s: %s\n' "$f" "$ln" "$(printf '%s' "$text" | sed 's/^[[:space:]]*//')"
      found=1
    done < <(grep -niE "$p" "$f" 2>/dev/null)
  done
done < <(find "$ROOT" -name '*.md' -not -path '*/.*' -not -name 'pseudo-spilman-leaves.md' | sort)

if [ "$found" = 1 ]; then
  echo "----------------------------------------------------------------"
  echo "Potential t/1143 drift above. If a line is a legitimate lineage"
  echo "note, add a reconciliation marker (e.g. mention t/1143 / interior)."
  exit 1
fi
echo "OK: no t/1143 drift smells found"
exit 0
