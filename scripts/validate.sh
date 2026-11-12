#!/usr/bin/env bash
# Render every environment overlay and validate the result.
#
#   scripts/validate.sh                         # all overlays in environments/
#   REQUIRE_KUBECONFORM=1 scripts/validate.sh   # fail instead of skipping schema validation (CI)
#
# Checks:
#   1. `kubectl kustomize` (or standalone `kustomize build`) renders each overlay.
#   2. Image policy: every image is tagged, no `latest`; prod images must be digest-pinned
#      (the explicit placeholder tag is tolerated until the first release exists).
#   3. No Secret objects are rendered (secrets never live in Git).
#   4. kubeconform schema validation (strict) of rendered overlays and argocd/ manifests.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="${OUT_DIR:-build/rendered}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.37.0}"
REQUIRE_KUBECONFORM="${REQUIRE_KUBECONFORM:-0}"
PLACEHOLDER_TAG="0.0.0-unreleased"
# Pinned commit of https://github.com/datreeio/CRDs-catalog (Argo CD Application/AppProject schemas).
CRDS_CATALOG_REF="89c736bdde38b5fecd0f8436ec5f3aa3679a3b86"
CRD_SCHEMA_LOCATION="https://raw.githubusercontent.com/datreeio/CRDs-catalog/${CRDS_CATALOG_REF}/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"

failures=0

log() { printf '%s\n' "$*"; }
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  failures=$((failures + 1))
}

render() {
  local overlay="$1"
  if command -v kubectl >/dev/null 2>&1; then
    kubectl kustomize "$overlay"
  elif command -v kustomize >/dev/null 2>&1; then
    kustomize build "$overlay"
  else
    printf 'ERROR: neither kubectl nor kustomize is installed\n' >&2
    exit 2
  fi
}

# Prints the image references found in a rendered manifest stream, one per line.
list_images() {
  sed -nE 's/^[[:space:]]*(-[[:space:]]+)?image:[[:space:]]*["'\'']?([^"'\''[:space:]]+)["'\'']?[[:space:]]*$/\2/p' "$1"
}

check_image() {
  local env="$1" image="$2"
  local name_and_tag="${image%%@*}"
  local digest=""
  if [[ "$image" == *@* ]]; then
    digest="${image#*@}"
    if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
      fail "[$env] malformed digest in image '$image'"
    fi
  fi

  # The tag is after the last ':' of the last path segment (a registry may carry a port).
  local last_segment="${name_and_tag##*/}"
  local tag=""
  if [[ "$last_segment" == *:* ]]; then
    tag="${last_segment##*:}"
  fi

  if [[ -z "$tag" ]]; then
    fail "[$env] image '$image' has no explicit tag"
  elif [[ "$tag" == "latest" ]]; then
    fail "[$env] image '$image' uses the mutable 'latest' tag"
  fi

  if [[ "$env" == "prod" && -z "$digest" && "$tag" != "$PLACEHOLDER_TAG" ]]; then
    fail "[$env] image '$image' must be pinned by digest (@sha256:...) in prod"
  fi
}

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*.yaml

overlays=()
for dir in environments/*/; do
  [[ -f "${dir}kustomization.yaml" ]] && overlays+=("${dir%/}")
done
if [[ ${#overlays[@]} -eq 0 ]]; then
  printf 'ERROR: no overlays found under environments/\n' >&2
  exit 2
fi

for overlay in "${overlays[@]}"; do
  env="${overlay##*/}"
  out="$OUT_DIR/$env.yaml"
  log "==> render $overlay"
  if ! render "$overlay" >"$out"; then
    fail "[$env] kustomize render failed"
    continue
  fi

  image_count=0
  while IFS= read -r image; do
    [[ -z "$image" ]] && continue
    image_count=$((image_count + 1))
    check_image "$env" "$image"
  done < <(list_images "$out")
  if [[ $image_count -eq 0 ]]; then
    fail "[$env] no container images found in rendered output"
  fi
  log "    images checked: $image_count"

  if grep -qE '^kind:[[:space:]]*Secret[[:space:]]*$' "$out"; then
    fail "[$env] rendered output contains a Secret; secrets must come from the secret store, not Git"
  fi
done

if command -v kubeconform >/dev/null 2>&1; then
  log "==> kubeconform (Kubernetes $KUBERNETES_VERSION, strict)"
  mkdir -p build/kubeconform-cache
  if ! kubeconform -strict -summary \
    -kubernetes-version "$KUBERNETES_VERSION" \
    -cache build/kubeconform-cache \
    -schema-location default \
    -schema-location "$CRD_SCHEMA_LOCATION" \
    "$OUT_DIR" argocd; then
    fail "kubeconform reported invalid manifests"
  fi
elif [[ "$REQUIRE_KUBECONFORM" == "1" ]]; then
  fail "kubeconform is required (REQUIRE_KUBECONFORM=1) but not installed"
else
  log "WARN: kubeconform not installed; schema validation skipped (CI enforces it)."
fi

if [[ $failures -gt 0 ]]; then
  printf '\n%d check(s) failed.\n' "$failures" >&2
  exit 1
fi
log ""
log "All checks passed for: ${overlays[*]}"
