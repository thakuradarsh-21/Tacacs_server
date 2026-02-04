############################################################
# TACACS+ remote setup Makefile (for Ubuntu VM)
#
# Usage:
#   make install-tacacs    # copy script + install on VM
#   make uninstall-tacacs  # remove TACACS+ from VM
#   make reinstall-tacacs  # uninstall then install
#
# Run these from inside the Documents/tacacs folder.
############################################################

## ======= CONFIGURE THESE VALUES ======= ##

# IP or hostname of the Ubuntu VM where TACACS+ will be installed
VM_IP ?= 192.168.199.14       # default VM IP (can override)

# SSH username for the VM (default: root)
VM_USER ?= root

# SSH password for the VM (default: tekken)
# NOTE: This is used via sshpass; make sure sshpass is installed on the machine
SSH_PASS ?= tekken

# Remote directory on the VM where scripts/config will live
REMOTE_DIR ?= /opt/tacacs-setup

## ======= INTERNAL VARIABLES (normally no need to change) ======= ##

SSH_BASE := ssh
SCP_BASE := scp

# Use sshpass with password-based SSH authentication
SSH := sshpass -p '$(SSH_PASS)' $(SSH_BASE) $(VM_USER)@$(VM_IP)
SCP := sshpass -p '$(SSH_PASS)' $(SCP_BASE)

LOCAL_SETUP_SCRIPT := setup_tacacs.sh

## ======= PHONY TARGETS ======= ##

.PHONY: help install-tacacs uninstall-tacacs reinstall-tacacs \
        push-scripts remote-shell check-connection

help:
	@echo "TACACS+ Ubuntu VM Makefile (Documents/tacacs)"
	@echo ""
	@echo "Configured VM:"
	@echo "  VM_IP      = $(VM_IP)"
	@echo "  VM_USER    = $(VM_USER)"
	@echo "  SSH_PASS   = ******** (password auth via sshpass)"
	@echo "  REMOTE_DIR = $(REMOTE_DIR)"
	@echo ""
	@echo "Targets:"
	@echo "  make check-connection   - Test SSH connection to VM"
	@echo "  make install-tacacs     - Run setup script on VM (no remote copy)"
	@echo "  make uninstall-tacacs   - Remove TACACS+ and its config from VM"
	@echo "  make reinstall-tacacs   - Uninstall then install again"
	@echo "  make remote-shell       - Open an interactive shell on VM"
	@echo ""
	@echo "Override defaults, e.g.:"
	@echo "  make install-tacacs VM_IP=10.0.0.5 VM_USER=root SSH_PASS=yourpass"

## Test SSH connection
check-connection:
	@echo "Testing SSH connection to $(VM_USER)@$(VM_IP)..."
	$(SSH) 'echo "SSH connection OK on $$(hostname)"'

## Copy scripts to VM
push-scripts:
	@if [ ! -f "$(LOCAL_SETUP_SCRIPT)" ]; then \
	  echo "ERROR: $(LOCAL_SETUP_SCRIPT) not found in current directory."; \
	  echo "       Please run make from inside Documents/tacacs or place setup_tacacs.sh here."; \
	  exit 1; \
	fi
	@echo "Creating remote directory $(REMOTE_DIR) on $(VM_USER)@$(VM_IP)..."
	# We are logging in as root by default, so no sudo needed; just ensure directory exists
	$(SSH) "mkdir -p $(REMOTE_DIR)"
	@echo "Copying scripts to VM..."
	$(SCP) "$(LOCAL_SETUP_SCRIPT)" $(VM_USER)@$(VM_IP):$(REMOTE_DIR)/
	@echo "Making scripts executable on VM..."
	$(SSH) "cd $(REMOTE_DIR) && chmod +x $(LOCAL_SETUP_SCRIPT)"

## Install TACACS+ on remote Ubuntu VM
install-tacacs:
	@if [ ! -f "$(LOCAL_SETUP_SCRIPT)" ]; then \
	  echo "ERROR: $(LOCAL_SETUP_SCRIPT) not found in current directory."; \
	  echo "       Please run make from inside Documents/tacacs or place setup_tacacs.sh here."; \
	  exit 1; \
	fi
	@echo "Running TACACS+ setup on $(VM_USER)@$(VM_IP) by streaming script (no remote copy, CRLF-safe)..."
	tr -d '\r' < "$(LOCAL_SETUP_SCRIPT)" | sshpass -p '$(SSH_PASS)' $(SSH_BASE) $(VM_USER)@$(VM_IP) 'bash -s'

## Uninstall TACACS+ and cleanup on remote Ubuntu VM
uninstall-tacacs:
	@echo "Uninstalling TACACS+ from $(VM_USER)@$(VM_IP)..."
	$(SSH) "sudo systemctl stop tacacs.service 2>/dev/null || true"
	$(SSH) "sudo systemctl disable tacacs.service 2>/dev/null || true"
	$(SSH) "sudo rm -f /etc/systemd/system/tacacs.service && sudo systemctl daemon-reload"
	$(SSH) "sudo apt-get remove -y tacacs+ || true"
	$(SSH) "sudo rm -rf /etc/tacacs+ /var/log/tac_plus.log"
	@echo "Optional: removing remote setup directory $(REMOTE_DIR)..."
	$(SSH) "sudo rm -rf $(REMOTE_DIR)"
	@echo "Uninstall complete."

## Reinstall (uninstall then install)
reinstall-tacacs: uninstall-tacacs install-tacacs

## Open interactive shell on VM
remote-shell:
	$(SSH)

