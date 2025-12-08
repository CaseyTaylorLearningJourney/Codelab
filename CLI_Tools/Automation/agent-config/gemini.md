# GEMINI.md

## Directory Overview

This directory contains documents related to setting up and securing a Docker environment on a Proxmox host. The focus is on establishing a secure and efficient Docker deployment by following best practices for containerization.

## Key Files

*   **`requirements.md`**: This file outlines the security requirements for the Docker deployment, including running containers as non-root users, using minimal base images, applying the principle of least privilege,
network segmentation, resource limiting, and vulnerability scanning. It also contains a log of the setup conversation and background information on the current infrastructure.

## Usage

The documents in this directory are intended to be used as a reference for configuring a secure Docker environment. The `requirements.md` file serves as a checklist and guide for implementing security best practices.

## Docker Host Setup

A Docker host has been configured on an AlmaLinux 9.6 VM. Following the security principle of least privilege, Docker is running in **rootless mode**.

*   **Dedicated User:** A non-root user named `user` has been created specifically for running Docker containers.
*   **Installation:** Docker was installed and configured for the `user` user, ensuring the Docker daemon and all containers run without root privileges. The setup involved:
    1.  Installing the Docker Engine.
    2.  Creating the `user` user.
    3.  Running the `dockerd-rootless-setuptool.sh` as the `user` user.
    4.  Configuring the necessary environment variables.
    5.  Enabling the Docker service as a `systemd` user service.
*   **Workloads:** All Docker workloads should be run under the `user` user to maintain the security benefits of the rootless installation.
