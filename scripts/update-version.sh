#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly GITHUB_REPO="OrcaSlicer/OrcaSlicer"
readonly NIGHTLY_TAG="nightly-builds"

readonly MAX_RETRIES=3
readonly RETRY_BASE_DELAY=2

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

retry() {
    local max_attempts="$1"
    local base_delay="$2"
    shift 2

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        local result
        result=$("$@") && [ -n "$result" ] && { echo "$result"; return 0; }

        if ((attempt < max_attempts)); then
            local delay=$((base_delay ** attempt))
            log_warn "Attempt $attempt/$max_attempts failed, retrying in ${delay}s..." >&2
            sleep "$delay"
        fi
    done

    return 1
}

get_current_version() {
    jq -r .version nightly.json 2>/dev/null || echo "unknown"
}

get_current_rev() {
    jq -r .rev nightly.json 2>/dev/null || echo "unknown"
}

fetch_nightly_rev() {
    git ls-remote "https://github.com/${GITHUB_REPO}.git" "refs/tags/${NIGHTLY_TAG}" | cut -f1
}

get_latest_rev() {
    retry "$MAX_RETRIES" "$RETRY_BASE_DELAY" fetch_nightly_rev
}

fetch_source_hash() {
    local rev="$1"

    # Use the "fake hash" method - try to evaluate with a dummy hash
    # and extract the correct hash from the error message
    local dummy_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

    # Backup current nightly.json
    cp nightly.json nightly.json.bak

    # Write temporary nightly.json with the new rev and dummy hash
    local date
    date=$(date -u +%Y-%m-%d)
    local short_rev
    short_rev=$(echo "$rev" | cut -c1-7)

    cat > nightly.json << EOF
{
  "version": "nightly-${date}-${short_rev}",
  "rev": "${rev}",
  "hash": "${dummy_hash}"
}
EOF

    # Try to build and capture the error with the correct hash
    # (--dry-run doesn't actually fetch, so we need a real build attempt)
    local output
    output=$(nix build .#default 2>&1 || true)

    # Restore original nightly.json
    mv nightly.json.bak nightly.json

    # Extract the correct hash from the error message
    # The error looks like: "got: sha256-XXXX..."
    local correct_hash
    correct_hash=$(echo "$output" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' | head -1)

    if [ -z "$correct_hash" ]; then
        log_error "Failed to extract hash from nix output"
        log_error "Output was: $output"
        return 1
    fi

    echo "$correct_hash"
}

update_nightly_json() {
    local rev="$1"
    local hash="$2"
    local date
    date=$(date -u +%Y-%m-%d)
    local short_rev
    short_rev=$(echo "$rev" | cut -c1-7)
    local version="nightly-${date}-${short_rev}"

    cat > nightly.json << EOF
{
  "version": "${version}",
  "rev": "${rev}",
  "hash": "${hash}"
}
EOF

    echo "$version"
}

verify_flake() {
    log_info "Verifying flake evaluation..."
    if ! nix eval .#packages.x86_64-linux.default.name > /dev/null 2>&1; then
        log_error "Flake evaluation failed"
        return 1
    fi

    log_info "Running flake check (no build)..."
    if ! nix flake check --no-build 2>&1; then
        log_error "Flake check failed"
        return 1
    fi

    return 0
}

update_flake_lock() {
    log_info "Updating flake.lock..."
    nix flake update
}

show_changes() {
    echo ""
    log_info "Changes made:"
    git diff --stat nightly.json flake.lock 2>/dev/null || true
}

ensure_in_repository_root() {
    if [ ! -f "flake.nix" ] || [ ! -f "nightly.json" ]; then
        log_error "flake.nix or nightly.json not found. Please run this script from the repository root."
        exit 1
    fi
}

ensure_required_tools_installed() {
    command -v nix >/dev/null 2>&1 || { log_error "nix is required but not installed."; exit 1; }
    command -v jq >/dev/null 2>&1 || { log_error "jq is required but not installed."; exit 1; }
    command -v git >/dev/null 2>&1 || { log_error "git is required but not installed."; exit 1; }
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --check    Only check for updates, don't apply"
    echo "  --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Update to latest nightly"
    echo "  $0 --check      # Check if update is available"
}

main() {
    local check_only=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                check_only=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    ensure_in_repository_root
    ensure_required_tools_installed

    local current_rev
    current_rev=$(get_current_rev)
    local current_version
    current_version=$(get_current_version)

    log_info "Current version: $current_version"
    log_info "Current rev: $current_rev"

    log_info "Fetching latest nightly-builds tag..."
    local latest_rev
    latest_rev=$(get_latest_rev) || {
        log_error "Failed to fetch latest rev after $MAX_RETRIES attempts"
        exit 1
    }
    log_info "Latest rev: $latest_rev"

    if [ "$current_rev" = "$latest_rev" ]; then
        log_info "Already up to date!"
        exit 0
    fi

    if [ "$check_only" = true ]; then
        log_info "Update available: $current_rev -> $latest_rev"
        exit 1  # Exit with non-zero to indicate update is available
    fi

    log_info "Fetching source hash..."
    local hash
    hash=$(fetch_source_hash "$latest_rev") || {
        log_error "Failed to fetch source hash"
        exit 1
    }
    log_info "Hash: $hash"

    log_info "Updating nightly.json..."
    local new_version
    new_version=$(update_nightly_json "$latest_rev" "$hash")
    log_info "New version: $new_version"

    update_flake_lock

    if ! verify_flake; then
        log_error "Verification failed, reverting changes"
        git checkout -- nightly.json flake.lock 2>/dev/null || true
        exit 1
    fi

    log_info "Successfully updated to $new_version"
    show_changes
}

main "$@"
