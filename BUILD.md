# BUILD — ansible-k8s-setup

- Repo: UncleD0886475978/ansible-k8s-setup — Public **fork**
- Stack actually found: Ansible playbooks to provision Kubernetes (kubeadm-style) nodes. Proving files: `k8s-pkg.yml` (1,942 B), `k8s-master.yml` (750 B), `k8s-workers.yml` (547 B), inventory `hosts` (80 B), `ansible.cfg`, `README.md` (571 B). No Terraform, Docker Compose, or K8s manifests at root.
## One-line install (fresh Ubuntu/Debian VM)

```bash
curl -fsSL https://raw.githubusercontent.com/UncleD0886475978/ansible-k8s-setup/main/setup.sh | bash
```

The script installs its own prerequisites — git/curl base tools and python3 + venv via apt, kubectl as the official binary (Ansible itself is installed with pip into a local `.venv`, never via apt) — then locates/clones the repo and syntax-checks the playbooks; kubectl is used validate-only and no cluster is provisioned. Alternative: clone the repo yourself and run `./setup.sh` from its root, as described below.

- What setup.sh does: Platform/base bootstrap first, then locates/clones the repo, bootstraps python3 + kubectl, resolves Ansible (system or pip venv), and runs `ansible-playbook -i hosts --syntax-check` on k8s-pkg, k8s-master, and k8s-workers (in that order). It does not run the playbooks; it prints the real ping + run sequence.
- Issue it prevents: Provisioning/reconfiguring real cluster nodes over SSH with a playbook that was never syntax-checked.
- Inspection note: root listing for every repo succeeded via GitHub connector. Deeper file reads were halted by a GitHub MCP HTTP 429 (rate limit) after willow-creek's subdirs/README were read; no further connector calls were made after the 429. Scripts therefore discover files at runtime where subdir contents were not individually enumerated. Root listing was complete (6 files, no subdirs).
