#!/usr/bin/env bash
# Hive Feed Price - Interactive Setup Script
# Creates or updates .env configuration interactively

set -euo pipefail

# ---------------------------
# Pretty printing helpers
# ---------------------------
bold="\033[1m"; reset="\033[0m"
green="\033[32m"; red="\033[31m"; yellow="\033[33m"; blue="\033[34m"; cyan="\033[36m"

ok()    { echo -e "${green}✔${reset} $*"; }
err()   { echo -e "${red}✘${reset} $*" >&2; }
warn()  { echo -e "${yellow}⚠${reset} $*"; }
info()  { echo -e "${blue}ℹ${reset} $*"; }
header(){ echo -e "\n${bold}▌ $*${reset}\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }
prompt(){ echo -en "${cyan}➜${reset} $*"; }

# ---------------------------
# Validation functions
# ---------------------------
validate_account() {
  local account="$1"
  # Hive accounts: 3-16 chars, lowercase, numbers, dots, dashes (no leading/trailing dots/dashes)
  if [[ "$account" =~ ^[a-z][a-z0-9.-]{1,14}[a-z0-9]$ ]] && [[ ! "$account" =~ \.\. ]] && [[ ! "$account" =~ -- ]]; then
    return 0
  fi
  return 1
}

validate_private_key() {
  local key="$1"
  # WIF format: starts with 5, 51 chars total, base58
  if [[ "$key" =~ ^5[HJK][1-9A-HJ-NP-Za-km-z]{49}$ ]]; then
    return 0
  fi
  return 1
}

# ---------------------------
# Main setup function
# ---------------------------
interactive_setup() {
  header "Hive Feed Price - Interactive Setup"
  echo
  info "This wizard will help you configure your Hive witness feed price bot."
  info "Press Enter to keep existing values (shown in brackets)."
  echo

  # Load existing values if .env exists
  local existing_account="" existing_key="" existing_nodes="" existing_interval=""
  if [ -f .env ]; then
    existing_account=$(grep -E "^HIVE_WITNESS_ACCOUNT=" .env 2>/dev/null | cut -d'=' -f2- | tr -d '"' || true)
    existing_key=$(grep -E "^HIVE_SIGNING_PRIVATE_KEY=" .env 2>/dev/null | cut -d'=' -f2- | tr -d '"' || true)
    existing_nodes=$(grep -E "^HIVE_RPC_NODES=" .env 2>/dev/null | cut -d'=' -f2- | tr -d '"' || true)
    existing_interval=$(grep -E "^FEED_INTERVAL=" .env 2>/dev/null | cut -d'=' -f2- | tr -d '"' || true)
    info "Found existing .env file. Current values will be shown."
    echo
  fi

  # ---------------------------
  # 1. Witness Account
  # ---------------------------
  header "Witness Account"
  local witness_account=""
  while true; do
    if [ -n "$existing_account" ]; then
      prompt "Enter your Hive witness account [${existing_account}]: "
    else
      prompt "Enter your Hive witness account: "
    fi
    read -r input_account
    
    # Use existing if empty input
    if [ -z "$input_account" ] && [ -n "$existing_account" ]; then
      witness_account="$existing_account"
      ok "Using existing account: $witness_account"
      break
    elif [ -n "$input_account" ]; then
      # Remove @ if present
      input_account="${input_account#@}"
      if validate_account "$input_account"; then
        witness_account="$input_account"
        ok "Account set: $witness_account"
        break
      else
        err "Invalid account name. Must be 3-16 lowercase characters (letters, numbers, dots, dashes)."
      fi
    else
      err "Witness account is required."
    fi
  done
  echo

  # ---------------------------
  # 2. Private Signing Key
  # ---------------------------
  header "Private Signing Key"
  warn "This is your witness ACTIVE or OWNER key (WIF format, starts with 5...)"
  warn "It will be stored encrypted by Beekeeper."
  local private_key=""
  while true; do
    if [ -n "$existing_key" ]; then
      # Mask existing key for display
      local masked_key="${existing_key:0:4}...${existing_key: -4}"
      prompt "Enter your private key [keep: ${masked_key}]: "
    else
      prompt "Enter your private key: "
    fi
    read -rs input_key  # -s for silent/hidden input
    echo  # New line after hidden input
    
    # Use existing if empty input
    if [ -z "$input_key" ] && [ -n "$existing_key" ]; then
      private_key="$existing_key"
      ok "Using existing key"
      break
    elif [ -n "$input_key" ]; then
      if validate_private_key "$input_key"; then
        private_key="$input_key"
        ok "Key validated and set"
        break
      else
        err "Invalid key format. Must be WIF format (starts with 5, 51 characters)."
      fi
    else
      err "Private key is required."
    fi
  done
  echo

  # ---------------------------
  # 3. Feed Interval Selection
  # ---------------------------
  header "Feed Publish Interval"
  info "How often should the bot publish your feed price?"
  echo
  echo "  1) Every 3 minutes   (frequent updates, more resources)"
  echo "  2) Every 10 minutes  (recommended for most witnesses)"
  echo "  3) Every 30 minutes  (balanced)"
  echo "  4) Every 1 hour      (conservative)"
  echo "  5) Every 6 hours     (minimal updates)"
  echo

  local feed_interval=""
  local default_choice="2"
  case "$existing_interval" in
    "3min")  default_choice="1" ;;
    "10min") default_choice="2" ;;
    "30min") default_choice="3" ;;
    "1hour") default_choice="4" ;;
    "6hour") default_choice="5" ;;
  esac

  while true; do
    prompt "Select interval [1-5, default: ${default_choice}]: "
    read -r interval_choice
    
    # Use default if empty
    [ -z "$interval_choice" ] && interval_choice="$default_choice"
    
    case "$interval_choice" in
      1) feed_interval="3min";  ok "Selected: Every 3 minutes"; break ;;
      2) feed_interval="10min"; ok "Selected: Every 10 minutes"; break ;;
      3) feed_interval="30min"; ok "Selected: Every 30 minutes"; break ;;
      4) feed_interval="1hour"; ok "Selected: Every 1 hour"; break ;;
      5) feed_interval="6hour"; ok "Selected: Every 6 hours"; break ;;
      *) err "Invalid choice. Please select 1-5." ;;
    esac
  done
  echo

  # ---------------------------
  # 4. RPC Nodes (optional)
  # ---------------------------
  header "RPC Nodes (Optional)"
  info "Configure Hive RPC nodes for API calls."
  info "Leave empty to use defaults: api.hive.blog, api.deathwing.me, api.openhive.network"
  echo

  local rpc_nodes=""
  local default_nodes="https://api.hive.blog,https://api.deathwing.me,https://api.openhive.network"
  
  if [ -n "$existing_nodes" ]; then
    prompt "RPC nodes [${existing_nodes}]: "
  else
    prompt "RPC nodes (comma-separated, or press Enter for defaults): "
  fi
  read -r input_nodes

  if [ -z "$input_nodes" ]; then
    if [ -n "$existing_nodes" ]; then
      rpc_nodes="$existing_nodes"
      ok "Using existing nodes"
    else
      rpc_nodes="$default_nodes"
      ok "Using default nodes"
    fi
  else
    rpc_nodes="$input_nodes"
    ok "Custom nodes set"
  fi
  echo

  # ---------------------------
  # 5. Review & Confirm
  # ---------------------------
  header "Configuration Summary"
  echo
  echo "  Witness Account:  ${witness_account}"
  echo "  Private Key:      ${private_key:0:4}...${private_key: -4}"
  echo "  Feed Interval:    ${feed_interval}"
  echo "  RPC Nodes:        ${rpc_nodes}"
  echo

  prompt "Save this configuration? [Y/n]: "
  read -r confirm
  if [[ "$confirm" =~ ^[Nn] ]]; then
    warn "Configuration cancelled. No changes made."
    exit 0
  fi

  # ---------------------------
  # 6. Write .env file
  # ---------------------------
  header "Saving Configuration"
  
  # Backup existing .env if present
  if [ -f .env ]; then
    local backup=".env.backup.$(date +%Y%m%d_%H%M%S)"
    cp .env "$backup"
    info "Backed up existing .env to $backup"
  fi

  cat > .env << EOF
# Hive Feed Price Tool - Environment Variables
# Generated by setup wizard on $(date)

# ============================================================================
# REQUIRED CONFIGURATION
# ============================================================================

# Witness account name (without @)
HIVE_WITNESS_ACCOUNT=${witness_account}

# Witness signature key (WIF format)
HIVE_SIGNING_PRIVATE_KEY=${private_key}

# ============================================================================
# NETWORK CONFIGURATION
# ============================================================================

# Comma-separated list of Hive RPC nodes (with automatic failover)
HIVE_RPC_NODES=${rpc_nodes}

# ============================================================================
# FEED PUBLISHING CONFIGURATION
# ============================================================================

# Feed publish interval
# Available options: 3min, 10min, 30min, 1hour, 6hour
FEED_INTERVAL=${feed_interval}
EOF

  ok "Configuration saved to .env"
  echo

  # Check if wallet needs cleaning (key changed)
  if [ -n "$existing_key" ] && [ "$existing_key" != "$private_key" ]; then
    warn "Private key changed! The Beekeeper wallet needs to be cleaned."
    prompt "Clean wallet now? [Y/n]: "
    read -r clean_confirm
    if [[ ! "$clean_confirm" =~ ^[Nn] ]]; then
      if [ -d storage_root-node/.beekeeper ]; then
        rm -rf storage_root-node/.beekeeper
        ok "Wallet cleaned"
      else
        info "No wallet found to clean"
      fi
    fi
  fi

  header "Setup Complete!"
  echo
  info "You can now start the bot with:"
  echo "  ./run.sh start"
  echo
  info "Other commands:"
  echo "  ./run.sh status   - Check status"
  echo "  ./run.sh logs     - View logs"
  echo "  ./run.sh stop     - Stop the bot"
  echo
}

# ---------------------------
# Quick setup (non-interactive)
# ---------------------------
quick_setup() {
  local account="$1"
  local key="$2"
  local interval="${3:-10min}"
  local nodes="${4:-https://api.hive.blog,https://api.deathwing.me,https://api.openhive.network}"

  if [ -z "$account" ] || [ -z "$key" ]; then
    err "Usage: ./setup.sh --quick <account> <private_key> [interval] [nodes]"
    exit 1
  fi

  cat > .env << EOF
# Hive Feed Price Tool - Environment Variables
# Generated by quick setup on $(date)

HIVE_WITNESS_ACCOUNT=${account}
HIVE_SIGNING_PRIVATE_KEY=${key}
HIVE_RPC_NODES=${nodes}
FEED_INTERVAL=${interval}
EOF

  ok "Quick setup complete. Configuration saved to .env"
}

# ---------------------------
# Usage
# ---------------------------
usage() {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  (no args)     Interactive setup wizard"
  echo "  --quick       Quick setup: ./setup.sh --quick <account> <key> [interval] [nodes]"
  echo "  --help        Show this help"
  echo
  echo "Intervals: 3min, 10min, 30min, 1hour, 6hour"
}

# ---------------------------
# Main
# ---------------------------
case "${1:-}" in
  --help|-h)
    usage
    ;;
  --quick)
    shift
    quick_setup "$@"
    ;;
  "")
    interactive_setup
    ;;
  *)
    err "Unknown option: $1"
    usage
    exit 1
    ;;
esac
