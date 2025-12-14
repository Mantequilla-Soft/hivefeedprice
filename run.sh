#!/usr/bin/env bash
# Hive Feed Price - Native Manager (no Docker)
# Usage: ./run.sh {install|start|stop|restart|logs|status|clean}
# Works on Ubuntu/Debian/WSL and general Linux

set -euo pipefail

# ---------------------------
# Settings
# ---------------------------
APP_NAME="hivefeedprice"
NODE_VERSION="22"           # Target Node.js via NVM
MIN_NODE_VERSION="20"       # Minimum major version required

# ---------------------------
# Pretty printing helpers
# ---------------------------
bold="\033[1m"; reset="\033[0m"
green="\033[32m"; red="\033[31m"; yellow="\033[33m"; blue="\033[34m"

ok()    { echo -e "${green}✔${reset} $*"; }
err()   { echo -e "${red}✘${reset} $*" >&2; }
warn()  { echo -e "${yellow}⚠${reset} $*"; }
info()  { echo -e "${blue}ℹ${reset} $*"; }
header(){ echo -e "\n${bold}▌ $*${reset}\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }
step()  { echo -e "➜ $*"; }

# ---------------------------
# Environment helpers
# ---------------------------
detect_environment() {
  if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "WSL"
    return
  fi
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "${NAME:-Linux}"
  else
    echo "Linux"
  fi
}

check_env_file() {
  if [ ! -f .env ]; then
    err ".env file not found"
    info "Create a .env file with required variables (see README)"
    exit 1
  fi
}

# ---------------------------
# Requirement checks
# ---------------------------
load_nvm() {
  if [ -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1090
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  fi
}

check_node() {
  load_nvm
  if ! command -v node >/dev/null 2>&1; then
    return 1
  fi
  local major
  major=$(node -p "process.versions.node.split('.')[0]")
  if [ "${major}" -lt "${MIN_NODE_VERSION}" ]; then
    warn "Node.js ${major} detected, but >= ${MIN_NODE_VERSION} required"
    return 1
  fi
  return 0
}

check_pnpm() { 
  load_nvm
  command -v pnpm >/dev/null 2>&1; 
}

check_dependencies() {
  [ -d node_modules ] && [ -f pnpm-lock.yaml ]
}

check_requirements() {
  local missing=()
  check_node || missing+=(node)
  check_pnpm || missing+=(pnpm)
  check_dependencies || missing+=(dependencies)
  if [ ${#missing[@]} -eq 0 ]; then
    return 0
  else
    err "Missing: ${missing[*]}"
    return 1
  fi
}

# ---------------------------
# Installers
# ---------------------------
install_node() {
  step "Installing Node.js ${NODE_VERSION} via NVM"
  if [ ! -d "$HOME/.nvm" ]; then
    info "Installing NVM..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  fi
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1090
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm install "$NODE_VERSION"
  nvm use "$NODE_VERSION"
  nvm alias default "$NODE_VERSION"
  check_node && ok "Node.js $(node --version) ready" || { err "Node install failed"; exit 1; }
}

install_pnpm() {
  step "Enabling pnpm via Corepack"
  if corepack enable pnpm; then
    ok "pnpm $(pnpm --version) enabled"
  else
    err "Failed to enable pnpm via corepack"
    info "Fallback: npm i -g pnpm"
    npm i -g pnpm || { err "pnpm installation failed"; exit 1; }
  fi
}

install_dependencies() {
  step "Installing dependencies"
  [ -f package.json ] || { err "package.json missing"; exit 1; }
  pnpm install && ok "Dependencies installed" || { err "pnpm install failed"; exit 1; }
}

install_all() {
  local env
  env=$(detect_environment)
  header "Setting up ${APP_NAME} (${env})"
  echo

  if ! check_node; then install_node; else ok "Node.js $(node --version) detected"; fi
  if ! check_pnpm; then install_pnpm; else ok "pnpm $(pnpm --version) detected"; fi
  if ! check_dependencies; then install_dependencies; else ok "Dependencies already installed"; fi

  echo
  header "Installation complete"
  
  # Offer interactive setup if no .env exists
  if [ ! -f .env ]; then
    echo
    info "No .env file found. Starting interactive setup..."
    echo
    if [ -f ./setup.sh ]; then
      ./setup.sh
    else
      warn "setup.sh not found. Please create .env manually (see .env.example)"
      info "Next: cp .env.example .env && edit .env"
    fi
  else
    info "Configuration found (.env exists)"
    info "Next: ./run.sh start"
    info "To reconfigure: ./run.sh setup"
  fi
}

run_setup() {
  header "Configuration Setup"
  if [ -f ./setup.sh ]; then
    ./setup.sh "$@"
  else
    err "setup.sh not found"
    exit 1
  fi
}

# ---------------------------
# App lifecycle
# ---------------------------
start_app() {
  header "Starting ${APP_NAME}"
  # Load NVM if present
  if [ -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1090
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  fi

  check_env_file
  if ! check_requirements; then
    info "Installing missing requirements..."
    install_all
  fi

  if pgrep -f "tsx.*src/index.ts" >/dev/null 2>&1; then
    warn "Application already running"
    info "PID: $(pgrep -f "tsx.*src/index.ts" | tr '\n' ' ')"
    return 0
  fi

  step "Launching in background (logs: hive-feed.log)"
  nohup pnpm start > hive-feed.log 2>&1 &
  local pid=$!
  sleep 2
  if kill -0 "$pid" 2>/dev/null; then
    echo "$pid" > .app_pid
    ok "Started (PID: $pid)"
    info "Manage: ./run.sh logs | ./run.sh stop | ./run.sh status"
  else
    err "Start failed; see hive-feed.log"
    exit 1
  fi
}

stop_app() {
  header "Stopping ${APP_NAME}"
  local stopped=false
  if [ -f .app_pid ]; then
    local pid
    pid=$(cat .app_pid)
    if kill -0 "$pid" 2>/dev/null; then
      step "Stopping PID ${pid}"
      kill "$pid" || true
      sleep 2
      if kill -0 "$pid" 2>/dev/null; then
        warn "Force killing ${pid}"
        kill -9 "$pid" 2>/dev/null || true
      fi
      stopped=true
    fi
    rm -f .app_pid
  fi
  if pgrep -f "tsx.*src/index.ts" >/dev/null 2>&1; then
    step "Killing stray tsx"
    pkill -f "tsx.*src/index.ts" 2>/dev/null || true
    stopped=true
  fi
  if [ "$stopped" = true ]; then ok "All processes stopped"; else warn "No running processes found"; fi
}

show_logs() {
  if [ -f hive-feed.log ]; then
    header "Live logs (Ctrl+C to exit)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    tail -f hive-feed.log
  else
    err "Log file not found: hive-feed.log"
    info "Start the app first: ./run.sh start"
    exit 1
  fi
}

show_status() {
  local env
  env=$(detect_environment)
  header "${APP_NAME} status"
  echo "Environment: ${env}"
  echo "Directory:   $(pwd)"
  echo

  if check_requirements; then
    ok "Requirements OK"
    echo "  - Node: $(node --version)"
    echo "  - pnpm: $(pnpm --version)"
  else
    warn "Some requirements are missing"
    info "Run: ./run.sh install"
  fi

  echo
  if [ -f .app_pid ] && kill -0 "$(cat .app_pid)" 2>/dev/null; then
    local pid
    pid=$(cat .app_pid)
    ok "RUNNING (PID: ${pid})"
    if command -v ps >/dev/null 2>&1; then
      echo "  - Memory: $(ps -p "$pid" -o rss= | awk '{print int($1/1024)"MB"}')"
      echo "  -   CPU%: $(ps -p "$pid" -o %cpu=)"
    fi
  else
    if pgrep -f "tsx.*src/index.ts" >/dev/null 2>&1; then
      ok "RUNNING (detected tsx process)"
    else
      err "NOT RUNNING"
    fi
  fi

  if [ -f hive-feed.log ]; then
    echo
    step "Recent logs (last 10 lines)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    tail -n 10 hive-feed.log || true
  fi

  echo
  step "Commands"
  echo "  ./run.sh install      - Install Node, pnpm, deps"
  echo "  ./run.sh start        - Start the app"
  echo "  ./run.sh stop         - Stop the app"
  echo "  ./run.sh restart      - Restart (stop + start)"
  echo "  ./run.sh logs         - Follow live logs"
  echo "  ./run.sh status       - Show status"
  echo "  ./run.sh clean        - Remove logs and PID"
  echo "  ./run.sh clean-wallet - Remove Beekeeper wallet (if key changed)"
}

clean_all() {
  header "Cleaning"
  stop_app 2>/dev/null || true
  rm -f hive-feed.log .app_pid
  ok "Cleanup done"
}

clean_wallet() {
  header "Cleaning Beekeeper Wallet"
  stop_app 2>/dev/null || true
  
  if [ -d storage_root-node/.beekeeper ]; then
    step "Removing wallet directory"
    rm -rf storage_root-node/.beekeeper
    ok "Wallet cleaned - new wallet will be created on next start"
  else
    warn "No wallet found"
  fi
  
  info "You can now start the app with: ./run.sh start"
}

usage() {
  header "${APP_NAME}"
  echo "Usage: $0 {install|setup|start|stop|restart|logs|status|clean|clean-wallet}"
  echo
  echo "Commands:"
  echo "  install      - Install Node.js, pnpm, and dependencies"
  echo "  setup        - Interactive configuration wizard"
  echo "  start        - Start the application"
  echo "  stop         - Stop the application"
  echo "  restart      - Restart the application"
  echo "  logs         - View real-time logs"
  echo "  status       - Show status"
  echo "  clean        - Remove logs and PID files"
  echo "  clean-wallet - Remove Beekeeper wallet (use when changing keys)"
  echo
  echo "Quick start: ./run.sh install && ./run.sh start"
}

case "${1:-status}" in
  install) install_all ;;
  setup)   shift; run_setup "$@" ;;
  start)   start_app   ;;
  stop)    stop_app    ;;
  restart) stop_app; sleep 2; start_app ;;
  logs)    show_logs   ;;
  status)  show_status ;;
  clean)   clean_all   ;;
  clean-wallet) clean_wallet ;;
  *) usage; exit 1 ;;
esac