#!/usr/bin/env bash
# setup.sh — ansible-k8s-setup (PUBLIC FORK: Install Kubernetes Cluster using Ansible Playbook)
# Safe by design: syntax-checks every playbook ONLY. The real run provisions a real
# Kubernetes cluster over SSH and is printed, never executed.
# Bootstrap: on a fresh Ubuntu/Debian VM this script INSTALLS its own prerequisites
# (git/curl base tools + python3/venv + kubectl official binary; Ansible itself via
# a pip venv — never apt). kubectl is installed for validation/next-step use only.
set -e
REPO="ansible-k8s-setup"
OWNER="UncleD0886475978"
CLONE_URL="https://github.com/${OWNER}/${REPO}.git"
TARGET_DIR="$HOME/repos/${REPO}"
RUN_ONELINE="curl -fsSL https://raw.githubusercontent.com/${OWNER}/${REPO}/main/setup.sh | bash"
echo "=== Setup: $REPO ==="

echo "==> Step 1/5: Platform check + base bootstrap (git, curl)"
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "ERROR: this script needs root or sudo to install packages."
    exit 1
  fi
fi
APT=0
if [ "$(uname -s)" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then APT=1; fi
INSTALLED=""
APT_UPDATED=""
note_installed() { INSTALLED="${INSTALLED} $1"; }
apt_update_once() {
  if [ -z "${APT_UPDATED}" ]; then $SUDO apt-get update -y; APT_UPDATED=1; fi
}
apt_install() {
  apt_update_once
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "$@"
}
if [ "${APT}" -eq 1 ]; then
  BASE_PKGS=""
  command -v git >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} git"
  command -v curl >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} curl"
  [ -f /etc/ssl/certs/ca-certificates.crt ] || BASE_PKGS="${BASE_PKGS} ca-certificates"
  command -v gpg >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} gnupg"
  if [ -n "${BASE_PKGS}" ]; then
    echo "    Installing base tools:${BASE_PKGS}"
    # shellcheck disable=SC2086
    apt_install ${BASE_PKGS}
    note_installed "${BASE_PKGS}"
  else
    echo "    Base tools already present (git, curl, ca-certificates, gnupg)."
  fi
else
  echo "    Non-apt platform detected — bootstrap will only CHECK tools and print install guidance."
fi

install_python() {
  if command -v python3 >/dev/null 2>&1 && python3 -c "import venv" >/dev/null 2>&1; then echo "    python3 + venv: already present ($(python3 --version))"; return 0; fi
  [ "${APT}" -eq 1 ] || return 1
  echo "    Installing python3, venv and pip..."
  apt_install python3 python3-venv python3-pip
  note_installed "python3"
}
install_kubectl() {
  if command -v kubectl >/dev/null 2>&1; then echo "    kubectl: already present"; return 0; fi
  if ! command -v sudo >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then return 1; fi
  echo "    Installing kubectl (official binary)..."
  KARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
  case "${KARCH}" in x86_64) KARCH="amd64" ;; aarch64) KARCH="arm64" ;; esac
  KVER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSLO "https://dl.k8s.io/release/${KVER}/bin/linux/${KARCH}/kubectl"
  $SUDO install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
  note_installed "kubectl"
}

echo "==> Step 2/5: Locate or clone ${REPO}"
if [ -f "$0" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
  SCRIPT_DIR="$PWD"
fi
if [ -d ".git" ] && command -v git >/dev/null 2>&1 && git remote get-url origin 2>/dev/null | grep -qi "${REPO}"; then
  REPO_DIR="$PWD"
elif [ -d "${SCRIPT_DIR}/.git" ] && command -v git >/dev/null 2>&1 && git -C "${SCRIPT_DIR}" remote get-url origin 2>/dev/null | grep -qi "${REPO}"; then
  REPO_DIR="${SCRIPT_DIR}"
elif [ -d "${TARGET_DIR}/.git" ]; then
  REPO_DIR="${TARGET_DIR}"
  git -C "${REPO_DIR}" pull --ff-only || echo "    (git pull skipped/failed — continuing with existing checkout)"
else
  if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is not installed. Install it: https://git-scm.com/downloads"
    exit 1
  fi
  mkdir -p "$HOME/repos"
  git clone "${CLONE_URL}" "${TARGET_DIR}"
  REPO_DIR="${TARGET_DIR}"
fi
cd "${REPO_DIR}"
echo "    Working in: ${REPO_DIR}"

echo "==> Step 3/5: Bootstrap prerequisites (python3 + kubectl; Ansible via venv next)"
MISSING_LIST=""
install_python || MISSING_LIST="${MISSING_LIST} python3(https://www.python.org/downloads/ — Ansible install docs: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)"
install_kubectl || MISSING_LIST="${MISSING_LIST} kubectl(https://kubernetes.io/docs/tasks/tools/)"
if [ -n "${MISSING_LIST}" ]; then
  echo "ERROR: could not auto-install on this platform. Missing:${MISSING_LIST}"
  echo "Install the tool(s) manually, then re-run this script."
  exit 1
fi
echo "    python3: $(python3 --version)"
echo "    kubectl: $(kubectl version --client 2>/dev/null | head -n 1 || echo present) (validate-only here — no cluster commands are run)"

echo "==> Step 4/5: Ansible — use system ansible, or a local venv"
ANSIBLE_PLAYBOOK=""
ANSIBLE_BIN=""
if command -v ansible-playbook >/dev/null 2>&1; then
  ANSIBLE_PLAYBOOK="ansible-playbook"
  ANSIBLE_BIN="ansible"
elif [ -x ".venv/bin/ansible-playbook" ]; then
  ANSIBLE_PLAYBOOK=".venv/bin/ansible-playbook"
  ANSIBLE_BIN=".venv/bin/ansible"
else
  echo "    ansible not found — creating .venv and installing ansible with pip..."
  echo "    (Manual alternative: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)"
  python3 -m venv .venv
  .venv/bin/pip install --upgrade pip >/dev/null
  .venv/bin/pip install ansible
  ANSIBLE_PLAYBOOK=".venv/bin/ansible-playbook"
  ANSIBLE_BIN=".venv/bin/ansible"
fi
${ANSIBLE_BIN} --version | head -1

echo "==> Step 5/5: Ansible syntax-check every playbook (inventory: hosts, config: ansible.cfg)"
for p in k8s-pkg.yml k8s-master.yml k8s-workers.yml; do
  if [ -f "$p" ]; then echo "-- $p"; ${ANSIBLE_PLAYBOOK} -i hosts --syntax-check "$p"; else echo "Missing expected playbook: $p"; fi
done
for p in $(find . -maxdepth 1 -name '*.yml' ! -name 'k8s-pkg.yml' ! -name 'k8s-master.yml' ! -name 'k8s-workers.yml'); do echo "-- extra: $p"; ${ANSIBLE_PLAYBOOK} -i hosts --syntax-check "$p"; done
echo ""
echo "Real run (NOT run — this provisions a real Kubernetes cluster over SSH and changes the target hosts):"
echo "  ansible-playbook -i hosts k8s-pkg.yml && ansible-playbook -i hosts k8s-master.yml && ansible-playbook -i hosts k8s-workers.yml"
echo "Check hosts first: ansible -i hosts all -m ping"

cat <<EOF

=================== BOOTSTRAP SUMMARY ===================
Installed during this run:${INSTALLED:- (nothing — all tools were already present)}
Working copy: ${REPO_DIR}
Next time, set up from scratch on any fresh Ubuntu VM with one line:
  ${RUN_ONELINE}
=========================================================
EOF

echo ""
echo "=== Next commands ==="
echo "Run/use:  ansible -i hosts all -m ping && ansible-playbook -i hosts k8s-pkg.yml && ansible-playbook -i hosts k8s-master.yml && ansible-playbook -i hosts k8s-workers.yml  # then on the master: kubectl get nodes"
echo "Stop:     on each node: sudo kubeadm reset -f  # no teardown playbook exists in this repo"
echo "Logs:     ansible -i hosts all -a 'kubectl get nodes' ; ssh to master: kubectl get pods -A"
