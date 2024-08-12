# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- Functionality to automatically update the CHANGELOG when merging pull requests.
- Implement Slack Notifications for GitHub Actions (Failures on Main Branch Only)
- Update Packer Template to Enable Logging and Auditing and Limit User Privileges
- Implement Shell Script to Enforce Minimum Password Length and Account Lockout Policy

### Added

- **Packer Repository**: Created the Packer repository and initialized the base AMI.
- **Github Actions CI/CD Pipeline**: Initialized the CI/CD pipeline for Packer to automate AMI builds and deployments. [#9]
- **CSI Hardening**: Implemented Packer to call shell scripts for applying Center for Internet Security (CSI) benchmarks. [#4]
- **Secure SSH and Firewall Configuration**: Updated the Packer template to configure secure SSH settings and firewall rules. [#8]
- **Service Management and Security Patches**: Implemented a shell script to disable unnecessary services and apply the latest security patches. [#18]
- **Password Policy Enforcement**: Added a shell script to enforce a minimum password length and implement an account lockout policy. [#11]
- **Time Synchronization and Kernel Hardening**: Implemented a shell script to configure time synchronization and secure kernel parameters. [#15]
- **Logging and Auditing**: Updated the Packer template to enable logging, auditing, and limit user privileges. [#13]

### Changed

- **Packer Template**: Updated the Packer template to include additional security configurations and ensure compliance with security standards.
- **CI/CD Pipeline**: Modified the pipeline to include additional steps for validating AMI builds against security benchmarks.

### Deprecated

- No deprecated features in this release.

### Removed

- No features or functionalities have been removed in this release.

### Fixed

- **Security Patches**: Fixed an issue where certain security patches were not being applied during the AMI build process.

### Security

- **SSH Configuration**: Implemented secure SSH settings to disable root login and enforce key-based authentication.
- **Firewall Rules**: Configured firewalls to deny all incoming connections except essential services (SSH, HTTP, HTTPS).
- **Service Management**: Disabled unnecessary services to reduce the attack surface of the AMI.
- **Password and Lockout Policies**: Enforced security policies for password management and account lockout to prevent brute-force attacks.
- **Kernel Hardening**: Applied security-focused kernel parameters to protect against common attack vectors.