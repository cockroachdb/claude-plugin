#!/usr/bin/env bash
set -euo pipefail

COCKROACHDB_DEFAULT_VERSION="25.4.9"
COCKROACHDB_HOME="${HOME}/.cockroachdb"
COCKROACHDB_BIN_DIR="${COCKROACHDB_HOME}/bin"
COCKROACHDB_BASE_DATA_DIR="${COCKROACHDB_HOME}/data"
COCKROACHDB_BASE_LOG_DIR="${COCKROACHDB_HOME}/logs"
NUM_NODES=3

BASE_URL="https://binaries.cockroachdb.com"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [COMMAND]

Commands:
  start       Download (if needed) and start a ${NUM_NODES}-node CockroachDB cluster (default)
  stop        Stop all nodes in the cluster
  status      Check if the cluster is running
  destroy     Stop the cluster and remove all data

Options:
  --version VERSION    CockroachDB version to install (default: ${COCKROACHDB_DEFAULT_VERSION})
  --binary PATH        Use an existing cockroach binary (skip download)
  --nodes N            Number of nodes (default: ${NUM_NODES})
  --port PORT          SQL port for node 1 (default: 26257; nodes 2,3 use 26258,26259)
  --http-port PORT     DB Console HTTP port for node 1 (default: 8080; nodes 2,3 use 8081,8082)
  --help               Show this help message

Environment variables:
  COCKROACHDB_VERSION  Same as --version
  COCKROACHDB_BINARY   Same as --binary

Examples:
  $(basename "$0")                           # Start 3-node cluster with defaults
  $(basename "$0") --nodes 1                 # Start single-node (lightweight)
  $(basename "$0") --version 25.4.7          # Start a specific version
  $(basename "$0") --binary /usr/local/bin/cockroach  # Use pre-installed binary
  $(basename "$0") stop                      # Stop all nodes
  $(basename "$0") destroy                   # Stop and delete all data
EOF
  exit 0
}

log() { echo "==> $*"; }
err() { echo "ERROR: $*" >&2; exit 1; }

detect_platform() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "${os}" in
    Linux)  PLATFORM_OS="linux" ;;
    Darwin) PLATFORM_OS="darwin" ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM_OS="windows" ;;
    *) err "Unsupported operating system: ${os}" ;;
  esac

  case "${arch}" in
    x86_64|amd64)  PLATFORM_ARCH="amd64" ;;
    arm64|aarch64) PLATFORM_ARCH="arm64" ;;
    *) err "Unsupported architecture: ${arch}" ;;
  esac
}

get_download_url() {
  local version="$1"
  local filename

  case "${PLATFORM_OS}-${PLATFORM_ARCH}" in
    linux-amd64)   filename="cockroach-v${version}.linux-amd64.tgz" ;;
    linux-arm64)   filename="cockroach-v${version}.linux-arm64.tgz" ;;
    darwin-amd64)  filename="cockroach-v${version}.darwin-10.9-amd64.tgz" ;;
    darwin-arm64)  filename="cockroach-v${version}.darwin-11.0-arm64.tgz" ;;
    windows-amd64) filename="cockroach-v${version}.windows-6.2-amd64.zip" ;;
    *) err "No binary available for ${PLATFORM_OS}-${PLATFORM_ARCH}" ;;
  esac

  echo "${BASE_URL}/${filename}"
}

get_archive_dir() {
  local version="$1"
  case "${PLATFORM_OS}-${PLATFORM_ARCH}" in
    linux-amd64)   echo "cockroach-v${version}.linux-amd64" ;;
    linux-arm64)   echo "cockroach-v${version}.linux-arm64" ;;
    darwin-amd64)  echo "cockroach-v${version}.darwin-10.9-amd64" ;;
    darwin-arm64)  echo "cockroach-v${version}.darwin-11.0-arm64" ;;
    windows-amd64) echo "cockroach-v${version}.windows-6.2-amd64" ;;
  esac
}

download_cockroach() {
  local version="$1"
  local url archive_dir tmp_dir

  if [ -x "${COCKROACHDB_BIN_DIR}/cockroach" ]; then
    local installed_version
    installed_version=$("${COCKROACHDB_BIN_DIR}/cockroach" version 2>/dev/null | grep 'Build Tag:' | awk '{print $3}' | sed 's/^v//')
    if [ "${installed_version}" = "${version}" ]; then
      log "CockroachDB v${version} already installed at ${COCKROACHDB_BIN_DIR}/cockroach"
      return 0
    fi
    log "Installed version v${installed_version} differs from requested v${version}, upgrading..."
  fi

  url=$(get_download_url "${version}")
  archive_dir=$(get_archive_dir "${version}")
  tmp_dir=$(mktemp -d)
  trap "rm -rf '${tmp_dir}'" EXIT

  log "Downloading CockroachDB v${version} for ${PLATFORM_OS}/${PLATFORM_ARCH}..."
  log "URL: ${url}"

  if command -v curl &>/dev/null; then
    curl -fsSL -o "${tmp_dir}/cockroach.tgz" "${url}"
  elif command -v wget &>/dev/null; then
    wget -q -O "${tmp_dir}/cockroach.tgz" "${url}"
  else
    err "Neither curl nor wget found. Install one and retry."
  fi

  log "Extracting..."
  mkdir -p "${COCKROACHDB_BIN_DIR}"

  if [[ "${PLATFORM_OS}" == "windows" ]]; then
    unzip -q "${tmp_dir}/cockroach.tgz" -d "${tmp_dir}"
  else
    tar xzf "${tmp_dir}/cockroach.tgz" -C "${tmp_dir}"
  fi

  cp "${tmp_dir}/${archive_dir}/cockroach" "${COCKROACHDB_BIN_DIR}/cockroach"
  chmod +x "${COCKROACHDB_BIN_DIR}/cockroach"

  trap - EXIT
  rm -rf "${tmp_dir}"

  log "Installed to ${COCKROACHDB_BIN_DIR}/cockroach"
}

node_pid_file() { echo "${COCKROACHDB_HOME}/cockroach-node${1}.pid"; }
node_sql_port() { echo $(( SQL_PORT + $1 - 1 )); }
node_http_port() { echo $(( HTTP_PORT + $1 - 1 )); }
node_rpc_port() { echo $(( 26357 + $1 - 1 )); }
node_data_dir() { echo "${COCKROACHDB_BASE_DATA_DIR}/node${1}"; }
node_log_dir() { echo "${COCKROACHDB_BASE_LOG_DIR}/node${1}"; }

node_is_running() {
  local node_num="$1"
  local pid_file
  pid_file=$(node_pid_file "${node_num}")

  if [ -f "${pid_file}" ]; then
    local pid
    pid=$(cat "${pid_file}")
    if kill -0 "${pid}" 2>/dev/null; then
      return 0
    fi
    rm -f "${pid_file}"
  fi
  return 1
}

any_node_running() {
  local i
  for i in $(seq 1 "${NUM_NODES}"); do
    if node_is_running "$i"; then
      return 0
    fi
  done

  # Fallback: check if a cockroach process is listening on the primary SQL port
  if lsof -i ":${SQL_PORT}" -sTCP:LISTEN 2>/dev/null | grep -q cockroach; then
    return 0
  fi

  # Last resort: SQL ping
  local cockroach_bin=""
  if [ -x "${COCKROACHDB_BIN_DIR}/cockroach" ]; then
    cockroach_bin="${COCKROACHDB_BIN_DIR}/cockroach"
  elif command -v cockroach &>/dev/null; then
    cockroach_bin="cockroach"
  fi
  if [ -n "${cockroach_bin}" ]; then
    if "${cockroach_bin}" sql --insecure --host="localhost:${SQL_PORT}" -e "SELECT 1" &>/dev/null; then
      return 0
    fi
  fi

  return 1
}

build_join_list() {
  local join_addrs=""
  local i
  for i in $(seq 1 "${NUM_NODES}"); do
    if [ -n "${join_addrs}" ]; then
      join_addrs="${join_addrs},"
    fi
    join_addrs="${join_addrs}localhost:$(node_rpc_port "$i")"
  done
  echo "${join_addrs}"
}

cmd_start() {
  local version="${VERSION}"
  local cockroach_bin="${BINARY}"

  if [ -z "${cockroach_bin}" ]; then
    if command -v cockroach &>/dev/null; then
      cockroach_bin="$(command -v cockroach)"
      log "Found cockroach on PATH: ${cockroach_bin}"
    else
      detect_platform
      download_cockroach "${version}"
      cockroach_bin="${COCKROACHDB_BIN_DIR}/cockroach"
    fi
  else
    [ -x "${cockroach_bin}" ] || err "Binary not found or not executable: ${cockroach_bin}"
  fi

  if any_node_running; then
    log "CockroachDB cluster is already running on port ${SQL_PORT}"
    print_connection_info "${cockroach_bin}"
    return 0
  fi

  if [ "${NUM_NODES}" -eq 1 ]; then
    start_single_node "${cockroach_bin}"
  else
    start_multi_node "${cockroach_bin}"
  fi
}

start_single_node() {
  local cockroach_bin="$1"
  local data_dir log_dir pid_file
  data_dir=$(node_data_dir 1)
  log_dir=$(node_log_dir 1)
  pid_file=$(node_pid_file 1)

  mkdir -p "${data_dir}" "${log_dir}"

  log "Starting single-node CockroachDB cluster..."
  "${cockroach_bin}" start-single-node \
    --insecure \
    --listen-addr="localhost:${SQL_PORT}" \
    --http-addr="localhost:${HTTP_PORT}" \
    --store="${data_dir}" \
    --log-dir="${log_dir}" \
    --background \
    --pid-file="${pid_file}"

  wait_for_ready "${cockroach_bin}"
  print_connection_info "${cockroach_bin}"
}

start_multi_node() {
  local cockroach_bin="$1"
  local join_list
  join_list=$(build_join_list)

  log "Starting ${NUM_NODES}-node CockroachDB cluster..."

  local i
  for i in $(seq 1 "${NUM_NODES}"); do
    local sql_port http_port rpc_port data_dir log_dir pid_file
    sql_port=$(node_sql_port "$i")
    http_port=$(node_http_port "$i")
    rpc_port=$(node_rpc_port "$i")
    data_dir=$(node_data_dir "$i")
    log_dir=$(node_log_dir "$i")
    pid_file=$(node_pid_file "$i")

    mkdir -p "${data_dir}" "${log_dir}"

    log "  Starting node ${i} (sql=:${sql_port}, http=:${http_port}, rpc=:${rpc_port})..."
    "${cockroach_bin}" start \
      --insecure \
      --listen-addr="localhost:${rpc_port}" \
      --sql-addr="localhost:${sql_port}" \
      --http-addr="localhost:${http_port}" \
      --store="${data_dir}" \
      --log-dir="${log_dir}" \
      --join="${join_list}" \
      --background \
      --pid-file="${pid_file}"
  done

  # Initialize the cluster if this is the first start (init is idempotent on already-initialized clusters)
  log "Initializing cluster..."
  "${cockroach_bin}" init --insecure --host="localhost:$(node_rpc_port 1)" 2>/dev/null || true

  wait_for_ready "${cockroach_bin}"

  local node_count
  node_count=$("${cockroach_bin}" sql --insecure --host="localhost:${SQL_PORT}" \
    -e "SELECT count(*) FROM crdb_internal.gossip_nodes;" --format=csv 2>/dev/null | tail -1) || node_count="?"
  log "Cluster ready with ${node_count} node(s)!"

  print_connection_info "${cockroach_bin}"
}

wait_for_ready() {
  local cockroach_bin="$1"
  local retries=0

  while [ $retries -lt 30 ]; do
    if "${cockroach_bin}" sql --insecure --host="localhost:${SQL_PORT}" -e "SELECT 1" &>/dev/null; then
      return 0
    fi
    retries=$((retries + 1))
    sleep 1
  done

  err "CockroachDB failed to start within 30 seconds. Check ${COCKROACHDB_BASE_LOG_DIR} for details."
}

cmd_stop() {
  local stopped=false

  local i
  for i in $(seq 1 "${NUM_NODES}"); do
    local pid_file
    pid_file=$(node_pid_file "$i")

    if [ -f "${pid_file}" ]; then
      local pid
      pid=$(cat "${pid_file}")
      if kill -0 "${pid}" 2>/dev/null; then
        log "Stopping node ${i} (PID ${pid})..."
        kill "${pid}"
        local retries=0
        while kill -0 "${pid}" 2>/dev/null && [ $retries -lt 15 ]; do
          retries=$((retries + 1))
          sleep 1
        done
        if kill -0 "${pid}" 2>/dev/null; then
          log "Forcefully terminating node ${i}..."
          kill -9 "${pid}" 2>/dev/null || true
        fi
        stopped=true
      fi
      rm -f "${pid_file}"
    fi
  done

  if [ "${stopped}" = true ]; then
    log "CockroachDB cluster stopped."
  else
    log "CockroachDB is not running."
  fi
}

cmd_status() {
  if any_node_running; then
    local running=0
    local i
    for i in $(seq 1 "${NUM_NODES}"); do
      if node_is_running "$i"; then
        local pid
        pid=$(cat "$(node_pid_file "$i")")
        log "Node ${i}: running (PID ${pid}, sql=:$(node_sql_port "$i"), http=:$(node_http_port "$i"))"
        running=$((running + 1))
      else
        log "Node ${i}: stopped"
      fi
    done
    log "Nodes running: ${running}/${NUM_NODES}"
    log "SQL endpoint: localhost:${SQL_PORT}"
    log "DB Console:   http://localhost:${HTTP_PORT}"
    log "Data dir:     ${COCKROACHDB_BASE_DATA_DIR}"
  else
    log "CockroachDB is not running."
    return 1
  fi
}

cmd_destroy() {
  cmd_stop
  if [ -d "${COCKROACHDB_BASE_DATA_DIR}" ]; then
    log "Removing data directory: ${COCKROACHDB_BASE_DATA_DIR}"
    rm -rf "${COCKROACHDB_BASE_DATA_DIR}"
  fi
  if [ -d "${COCKROACHDB_BASE_LOG_DIR}" ]; then
    log "Removing log directory: ${COCKROACHDB_BASE_LOG_DIR}"
    rm -rf "${COCKROACHDB_BASE_LOG_DIR}"
  fi
  log "All CockroachDB data destroyed."
}

print_connection_info() {
  local cockroach_bin="$1"
  local version_info
  version_info=$("${cockroach_bin}" version 2>/dev/null | grep 'Build Tag:' | awk '{print $3}') || version_info="unknown"

  cat <<EOF

--- CockroachDB Local Cluster (${NUM_NODES}-node) ---
  Version:      ${version_info}
  SQL:          postgresql://root@localhost:${SQL_PORT}/defaultdb?sslmode=disable
  DB Console:   http://localhost:${HTTP_PORT}
  Data dir:     ${COCKROACHDB_BASE_DATA_DIR}
  Log dir:      ${COCKROACHDB_BASE_LOG_DIR}
EOF

  if [ "${NUM_NODES}" -gt 1 ]; then
    echo "  Nodes:"
    local i
    for i in $(seq 1 "${NUM_NODES}"); do
      echo "    node${i}: sql=:$(node_sql_port "$i")  http=:$(node_http_port "$i")  rpc=:$(node_rpc_port "$i")"
    done
  fi

  cat <<EOF

Environment variables for MCP Toolbox:
  export COCKROACHDB_HOST=localhost
  export COCKROACHDB_PORT=${SQL_PORT}
  export COCKROACHDB_USER=root
  export COCKROACHDB_PASSWORD=
  export COCKROACHDB_DATABASE=defaultdb
  export COCKROACHDB_SSLMODE=disable

EOF
}

# Parse arguments
VERSION="${COCKROACHDB_VERSION:-${COCKROACHDB_DEFAULT_VERSION}}"
BINARY="${COCKROACHDB_BINARY:-}"
SQL_PORT="26257"
HTTP_PORT="8080"
COMMAND="start"

while [ $# -gt 0 ]; do
  case "$1" in
    --version)   VERSION="$2"; shift 2 ;;
    --binary)    BINARY="$2"; shift 2 ;;
    --nodes)     NUM_NODES="$2"; shift 2 ;;
    --port)      SQL_PORT="$2"; shift 2 ;;
    --http-port) HTTP_PORT="$2"; shift 2 ;;
    --help|-h)   usage ;;
    start|stop|status|destroy) COMMAND="$1"; shift ;;
    *) err "Unknown argument: $1. Run with --help for usage." ;;
  esac
done

[ "${NUM_NODES}" -ge 1 ] 2>/dev/null || err "--nodes must be a positive integer"

case "${COMMAND}" in
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  status)  cmd_status ;;
  destroy) cmd_destroy ;;
esac
