#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Enable debugging
set -x

sleep 15
echo "#################### Executing 001-critical-standards.sh ######################"

# Function to disable root login and enforce key-based authentication in the SSH configuration file
configure_ssh_security() {
  # Check if the system is Debian-based or Red Hat-based
  if [ -f /etc/debian_version ]; then
    echo "Detected Debian-based system."
  elif [ -f /etc/redhat-release ]; then
    echo "Detected Red Hat-based system."
  else
    echo "Unsupported Linux distribution."
    return 1
  fi

  SSH_CONFIG_FILE="/etc/ssh/sshd_config"

  # Backup the original SSH configuration file
  cp "$SSH_CONFIG_FILE" "${SSH_CONFIG_FILE}.backup"
  echo "Original SSH configuration file backed up to ${SSH_CONFIG_FILE}.backup."

  # Disable root login
  if ! grep -q "^PermitRootLogin" "$SSH_CONFIG_FILE"; then
    echo "PermitRootLogin no" >> "$SSH_CONFIG_FILE"
  else
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG_FILE"
  fi
  echo "Root login disabled successfully."

  # Enforce key-based authentication
  if ! grep -q "^PubkeyAuthentication" "$SSH_CONFIG_FILE"; then
    echo "PubkeyAuthentication yes" >> "$SSH_CONFIG_FILE"
  else
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSH_CONFIG_FILE"
  fi
  echo "Public key authentication enabled successfully."

  # Disable password authentication
  if ! grep -q "^PasswordAuthentication" "$SSH_CONFIG_FILE"; then
    echo "PasswordAuthentication no" >> "$SSH_CONFIG_FILE"
  else
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSH_CONFIG_FILE"
  fi
  echo "Password authentication disabled successfully."

  # Determine SSH service name and restart it
  if systemctl list-units --type=service | grep -q sshd.service; then
    SSH_SERVICE="sshd.service"
  elif systemctl list-units --type=service | grep -q ssh.service; then
    SSH_SERVICE="ssh.service"
  else
    echo "Failed to detect SSH service. Please check the SSH configuration."
    return 1
  fi

  if systemctl restart "$SSH_SERVICE"; then
    echo "$SSH_SERVICE restarted successfully."
  else
    echo "Failed to restart $SSH_SERVICE. Please check the SSH configuration."
    return 1
  fi

  echo "SSH security configuration completed successfully."
  return 0
}

# Function to configure the firewall
configure_firewall() {
  if [ -f /etc/debian_version ]; then
    # Debian-based systems
    if ! command -v ufw > /dev/null; then
      echo "ufw not detected. Installing ufw..."
      apt-get update -y
      apt-get install -y ufw
      echo "ufw installation completed."
    else
      echo "ufw is already installed."
    fi

    echo "Configuring firewall using ufw..."
    # Enable ufw
    ufw --force enable
    # Allow necessary services by port numbers
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    # Deny all other incoming connections by default
    ufw default deny incoming
    # Allow all outgoing connections by default
    ufw default allow outgoing
    # Reload ufw to apply changes
    ufw reload
    # Check ufw status
    ufw status verbose

  elif [ -f /etc/redhat-release ]; then
    # RedHat-based systems
    if ! command -v firewalld > /dev/null; then
      echo "firewalld not detected. Installing firewalld..."
      yum install -y firewalld
      echo "firewalld installation completed."
    else
      echo "firewalld is already installed."
    fi

    echo "Configuring firewall using firewalld..."
    # Start and enable firewalld
    systemctl start firewalld
    systemctl enable firewalld
    # Allow necessary services by port numbers
    firewall-cmd --permanent --add-port=22/tcp
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=443/tcp
    # Reload firewalld to apply changes
    firewall-cmd --reload
    # Check firewalld status
    firewall-cmd --list-all

  else
    echo "Unsupported Linux distribution."
    return 1
  fi

  echo "Firewall configuration completed successfully."
  return 0
}

# Call the SSH security configuration function
configure_ssh_security
exit_code=$?
echo $exit_code > /opt/script-error-code

# If the SSH security configuration was successful, configure the firewall
if [ $exit_code -eq 0 ]; then
  configure_firewall
  exit_code=$?
fi

echo "##### SSH security and firwall configuration function execution completed #####" > /var/log/001-critical-standards.log

# Function to log messages
LOG_FILE="/var/log/system_update.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to check the OS type and define non-essential services
check_os() {
    if [ -f /etc/redhat-release ]; then
        OS="RedHat"
        log "Detected OS: RedHat"
        # NON_ESSENTIAL_SERVICES=("rhsmcertd" "snapd" "polkit" "acpid" "snap.amazon-ssm-agent.amazon-ssm-agent")
        NON_ESSENTIAL_SERVICES=("rhsmcertd")
    elif [ -f /etc/debian_version ]; then
        OS="Debian"
        log "Detected OS: Debian"
        NON_ESSENTIAL_SERVICES=("snapd" "polkit" "acpid")
    else
        log "Unsupported OS."
        exit 1
    fi
}

# Function to disable non-essential services on Debian-based systems
disable_non_essential_services_debian() {
    log "Disabling non-essential services on Debian-based system..."
    for service in "${NON_ESSENTIAL_SERVICES[@]}"; do
        systemctl stop "$service" 2>>/var/log/system_update.log
        if [ $? -ne 0 ]; then
            log "Failed to stop $service"
            continue
        fi
        systemctl disable "$service" 2>>/var/log/system_update.log
        if [ $? -ne 0 ]; then
            log "Failed to disable $service"
            continue
        fi
    done
    return 0
}

# Function to disable non-essential services on RedHat-based systems
disable_non_essential_services_redhat() {
    log "Disabling non-essential services on RedHat-based system..."
    for service in "${NON_ESSENTIAL_SERVICES[@]}"; do
        systemctl stop "$service" 2>>/var/log/system_update.log
        if [ $? -ne 0 ]; then
            log "Failed to stop $service"
            continue
        fi
        systemctl disable "$service" 2>>/var/log/system_update.log
        if [ $? -ne 0 ]; then
            log "Failed to disable $service"
            continue
        fi
    done
    return 0
}

# Function to clean and update the package repository on Debian-based systems
clean_update_repo_debian() {
    log "Cleaning and updating package repository on Debian-based system..."
    rm -rf /var/lib/apt/lists/* 2>>/var/log/system_update.log
    if [ $? -ne 0 ]; then
        log "Failed to clean package lists"
        return 1
    fi

    apt-get clean 2>>/var/log/system_update.log
    if [ $? -ne 0 ]; then
        log "Failed to clean apt cache"
        return 1
    fi

    apt-get update -y 2>>/var/log/system_update.log
    if [ $? -ne 0 ]; then
        log "Failed to update package lists"
        return 1
    fi

    return 0
}

# Function to apply the latest security patches on Debian-based systems
apply_patches_debian() {
    log "Applying latest security patches on Debian-based system..."
    apt-get upgrade -y 2>>/var/log/system_update.log
    if [ $? -ne 0 ]; then
        log "Failed to upgrade packages"
        return 1
    fi

    apt-get dist-upgrade -y 2>>/var/log/system_update.log
    if [ $? -ne 0 ]; then
        log "Failed to perform dist-upgrade"
        return 1
    fi

    apt-get autoremove -y 2>>/var/log/system_update.log
    if [ $? -ne 0 ]; then
        log "Failed to autoremove packages"
        return 1
    fi
    return 0
}

# Function to apply the latest security patches on RedHat-based systems
apply_patches_redhat() {
    log "Applying latest security patches on RedHat-based system..."
    yum update -y 2>>/var/log/system_update.log
    if [ $? -ne 0 ]; then
        log "Failed to update packages"
        return 1
    fi

    yum upgrade -y 2>>/var/log/system_update.log
    if [ $? -ne 0 ]; then
        log "Failed to upgrade packages"
        return 1
    fi
    return 0
}

# Main script execution
log "Starting system update script."

check_os

if [ "$OS" = "Debian" ]; then
    clean_update_repo_debian
    CLEAN_UPDATE_EXIT_CODE=$?
    if [ $CLEAN_UPDATE_EXIT_CODE -ne 0 ]; then
        log "Failed to clean and update package repository. Exiting..."
        exit 1
    fi

    disable_non_essential_services_debian
    DISABLE_EXIT_CODE=$?
    if [ $DISABLE_EXIT_CODE -ne 0 ]; then
        log "Failed to disable unnecessary services. Exiting..."
        exit 1
    fi

    apply_patches_debian
    PATCH_EXIT_CODE=$?
    if [ $PATCH_EXIT_CODE -ne 0 ]; then
        log "Failed to apply security patches. Exiting..."
        exit 1
    fi

elif [ "$OS" = "RedHat" ]; then
    disable_non_essential_services_redhat
    DISABLE_EXIT_CODE=$?
    if [ $DISABLE_EXIT_CODE -ne 0 ]; then
        log "Failed to disable unnecessary services. Exiting..."
        exit 1
    fi

    apply_patches_redhat
    PATCH_EXIT_CODE=$?
    if [ $PATCH_EXIT_CODE -ne 0 ]; then
        log "Failed to apply security patches. Exiting..."
        exit 1
    fi
fi

log "System has been successfully updated and only essential services are enabled."
echo "System update successfully completed. Check /var/log/system_update.log for details."

# Define log file paths
LOG_FILE="/var/log/enforce_password_length.log"
ERROR_LOG_FILE="/var/log/enforce_password_length_error.log"

# Function to create log files and set permissions
initialize_logs() {
  sudo touch "$LOG_FILE" "$ERROR_LOG_FILE" 2>/dev/null
  sudo chmod 664 "$LOG_FILE" "$ERROR_LOG_FILE" 2>/dev/null
  sudo chown root:root "$LOG_FILE" "$ERROR_LOG_FILE" 2>/dev/null
}

# Function to log messages
log_message() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - INFO - $1" >> "$LOG_FILE"
}

# Function to log errors
log_error() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - ERROR - $1" >> "$ERROR_LOG_FILE"
}

# Function to enforce minimum password length
enforce_password_length() {
  local expected_min_len=12
  local config_file="/etc/login.defs"
  local min_len_setting="PASS_MIN_LEN"

  initialize_logs

  if [ -f /etc/debian_version ] || [ -f /etc/redhat-release ]; then
    # Update or add PASS_MIN_LEN setting
    sudo sed -i "s/^#*\s*${min_len_setting}.*/${min_len_setting}   ${expected_min_len}/" "$config_file"
    if [ $? -ne 0 ]; then
      log_error "Failed to update ${min_len_setting} in ${config_file}."
      return 1
    fi

    # Validate the change
    current_min_len=$(grep "^${min_len_setting}" "$config_file" | awk '{print $2}' | head -n 1 | tr -d '[:space:]')
    if [ "$current_min_len" -eq "$expected_min_len" ]; then
      log_message "Password length enforcement was successful."
      return 0
    else
      log_error "Password length enforcement failed. Current value: $current_min_len"
      return 1
    fi
  else
    log_error "Unsupported system."
    return 1
  fi
}

# Run the function and log the result
enforce_password_length

# Provide feedback based on the function result
if [ $? -eq 0 ]; then
  echo "Configuration change applied and validated successfully."
else
  echo "Configuration change failed or validation failed."
fi


# Define log file paths
LOG_FILE="/var/log/enforce_password_length.log"
ERROR_LOG_FILE="/var/log/enforce_password_length_error.log"

# Function to create log files and set permissions
initialize_logs() {
  sudo touch "$LOG_FILE" "$ERROR_LOG_FILE" 2>/dev/null
  sudo chmod 664 "$LOG_FILE" "$ERROR_LOG_FILE" 2>/dev/null
  sudo chown root:root "$LOG_FILE" "$ERROR_LOG_FILE" 2>/dev/null
}

# Function to log messages
log_message() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - INFO - $1" >> "$LOG_FILE"
}

# ACCOUNT LOCKOUT SET-UP; Function to log errors
log_error() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - ERROR - $1" >> "$ERROR_LOG_FILE"
}


# Log file location
log_file="/var/log/pam_update.log"

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
}

# Function to handle errors
handle_error() {
    log "Error: $1"
    exit 1
}

# Define the line to be added
line="auth required pam_tally2.so deny=5 unlock_time=900"

# Determine the distribution and set the file accordingly
if [ -f /etc/redhat-release ]; then
    file="/etc/pam.d/system-auth"
    file_ac="/etc/pam.d/password-auth"
    log "Detected Red Hat-based system. Using files: $file and $file_ac"
elif [ -f /etc/debian_version ]; then
    file="/etc/pam.d/common-auth"
    log "Detected Debian-based system. Using file: $file"
else
    handle_error "Unsupported distribution. Exiting."
fi

# Function to apply the configuration
apply_config() {
    local pam_file=$1
    log "Applying configuration to $pam_file"
    
    # Check if the line already exists in the file
    if ! grep -qF "$line" "$pam_file"; then
        # Check the exit code of grep
        if [ $? -ne 0 ]; then
            handle_error "Failed to check if the line exists in $pam_file."
        fi

        # Find the line number where the primary block starts
        primary_block_start=$(grep -n "^auth" "$pam_file" | head -n 1 | cut -d: -f1)

        # Check if the primary block start line number was found
        if [ -n "$primary_block_start" ]; then
            # Insert the line after the primary block start
            sed -i "${primary_block_start}a $line" "$pam_file"
            if [ $? -eq 0 ]; then
                log "Line added successfully to $pam_file."
            else
                handle_error "Failed to add line to $pam_file."
            fi
        else
            handle_error "Primary block not found in $pam_file."
        fi
    else
        log "Line already exists in $pam_file."
    fi
}

# Apply configuration to the appropriate file(s)
apply_config "$file"

# For Red Hat-based systems, also update the password-auth file
if [ -f /etc/redhat-release ]; then
    apply_config "$file_ac"
fi

log "Configuration applied successfully."
echo "Functions to disable non-essential services, clean and update the package repository completed" > /var/log/001-critical-standards.log
echo "Functions to enforce minimum password length, apply the latest security patches completed" > /var/log/001-critical-standards.log

# Function to enable logging and auditing
# Log file path
LOG_FILE="/var/log/enable_logging_auditing.log"

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting system logging and auditing script."

# Function to enable logging and auditing
enable_logging_auditing() {
    # Check if the system is Debian-based or RedHat-based
    # if [ -f /etc/debian_version ]; then
    if [ "$OS" = "Debian" ]; then
        log "Detected Debian-based system."

        # Install auditd on Debian-based systems
        log "Installing auditd..."
        apt-get install auditd audispd-plugins -y 2>&1 | tee -a "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "Error: Failed to install auditd on Debian-based system."
            return 1
        fi

        # Ensure auditd starts on boot and is running
        log "Enabling and starting auditd service..."
        systemctl enable auditd 2>&1 | tee -a "$LOG_FILE"
        systemctl start auditd 2>&1 | tee -a "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "Error: Failed to enable/start auditd service on Debian-based system."
            return 1
        fi

    # elif [ -f /etc/redhat-release ]; then
    elif [ "$OS" = "RedHat" ]; then

        log "Detected RedHat-based system."

        # Install auditd on RedHat-based systems
        log "Installing auditd..."
        yum install audit -y 2>&1 | tee -a "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "Error: Failed to install auditd on RedHat-based system."
            return 1
        fi

        # Ensure auditd starts on boot and is running
        log "Enabling and starting auditd service..."
        systemctl enable auditd 2>&1 | tee -a "$LOG_FILE"
        systemctl start auditd 2>&1 | tee -a "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "Error: Failed to enable/start auditd service on RedHat-based system."
            return 1
        fi

    else
        log "Unsupported operating system."
        return 1
    fi

    # Validate auditd is logging appropriate events
    log "Validating auditd is logging appropriate events..."
    auditctl -l 2>&1 | tee -a "$LOG_FILE"
    if [ $? -ne 0 ]; then
        log "Error: Auditd validation failed."
        return 1
    fi

    log "Auditd logging and auditing setup completed successfully."
    return 0
}

# Call the function
enable_logging_auditing

# Check the result of the function call
if [ $? -eq 0 ]; then
    log "Logging and auditing enabled successfully."
else
    log "Failed to enable logging and auditing."
fi

log "logging and auditing has been successfully enabled."
echo "Functions to enable logging and auditing completed" > /var/log/001-critical-standards.log
echo "System update successfully completed. Check /var/log/enable_logging_auditing.log for details."

# Function to limit user privileges
# Log file path
LOG_FILE="/var/log/limit_user_privileges.log"

# Function to log messages
log_message() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - INFO - $1" >> "$LOG_FILE"
}

# Function to log errors
log_error() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - ERROR - $1" >> "$LOG_FILE"
}

# Function to limit user privileges
limit_user_privileges() {
  local authorized_user="$1"
  
  if [ -z "$authorized_user" ]; then
    log_error "No authorized user provided. Exiting."
    return 1
  fi

  # Detect OS and set group accordingly
  if [ -f /etc/debian_version ]; then
    sudo_group="sudo"
  elif [ -f /etc/redhat-release ]; then
    sudo_group="wheel"
  else
    log_error "Unsupported operating system."
    return 1
  fi

  # Configure sudoers file to limit root access
  bash -c "echo '$authorized_user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/$authorized_user"
  chmod 440 /etc/sudoers.d/$authorized_user
  if [ $? -ne 0 ]; then
    log_error "Failed to configure sudoers file for $authorized_user."
    return 1
  else
    log_message "Sudoers file configured for $authorized_user."
  fi

  # Ensure only authorized users have sudo access
  usermod -aG "$sudo_group" "$authorized_user"
  if [ $? -ne 0 ]; then
    log_error "Failed to add $authorized_user to $sudo_group group."
    return 1
  else
    log_message "$authorized_user added to $sudo_group group."
  fi

  # Validate sudo configuration
  visudo -c > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    log_error "Sudo configuration validation failed."
    return 1
  else
    log_message "Sudo configuration validated successfully."
  fi

  # Capture the exit code
  exit_code=$?
  # Return the exit code
  return $exit_code
}

 # Detect OS and set authorized_user accordingly
  if [ -f /etc/debian_version ]; then
    authorized_user="ubuntu"
  elif [ -f /etc/redhat-release ]; then
    authorized_user="ec2-user"
    # For installing and configuring sssd service on redhat
    yum install sssd -y

    cat > /tmp/block_to_inject <<EOF
# BEGIN INJECTED BLOCK
#/etc/sssd/sssd.conf
 
[sssd]
config_file_version = 2
services = nss, pam
domains = example.com

[nss]
filter_groups = root
filter_users = root

[pam]

[domain/example.com]
id_provider = ldap
auth_provider = ldap
ldap_uri = ldap://ldap.example.com
ldap_search_base = dc=example,dc=com
# END INJECTED BLOCK
EOF

    tee -a /etc/sssd/sssd.conf < /tmp/block_to_inject > /dev/null

    chmod 600 /etc/sssd/sssd.conf
    chown root:root /etc/sssd/sssd.conf
    systemctl enable sssd
    systemctl start sssd
    usermod -aG wheel ec2-user
  else
    log_error "Unsupported operating system."
    return 1
  fi
# Example usage:
limit_user_privileges "$authorized_user"

# Check the result of the function call
if [ $? -eq 0 ]; then
  log_message "User privileges limited successfully."
else
  log_error "Failed to limit user privileges."
fi

log "Function to limit user privileges successfully completed."
echo "Function to limit user privileges completed" > /var/log/001-critical-standards.log
echo "System update successfully completed. Check /var/log/limit_user_privileges.log for details."

# Display the final exit code before exiting
echo "Final exit code: $exit_code"
exit $exit_code
