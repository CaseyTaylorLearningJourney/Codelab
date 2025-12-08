# Project Requirements & Conversation Log

This document outlines the security requirements for Docker deployments and contains a secondary list of Security Requirements and Infrastracture details outside of Docker deployments as well to keep from overprovisioning

## Docker Security Requirements Checklist

1.  **Run as a Non-Root User:** Containers should not be run as root. Use the `USER` instruction in Dockerfiles and specify `PUID`/`PGID` for images that support it. Run the Docker daemon in rootless mode on the host VM.
2.  **Use Minimal Base Images:** Start with small, trusted base images like `alpine` or "distroless" to reduce the attack surface.
3.  **Principle of Least Privilege:** Grant containers only the capabilities they absolutely need. Drop all capabilities by default (`cap_drop: - ALL`) and only add back what is essential. Use read-only filesystems where possible.
4.  **Network Segmentation:** Use custom Docker networks to isolate container groups. Avoid using the default `bridge` network or `host` networking.
5.  **Resource Limiting:** Set CPU and memory limits for all containers to prevent resource exhaustion and potential denial-of-service attacks.
6.  **Scan Images for Vulnerabilities:** Regularly scan Docker images for known vulnerabilities using tools like Trivy or Docker Scout.
##

### Conversation and Infrastructure Background

1. **Balance security and performance but always keep security first.** This is not limited to this list but always make sure secrets are managed properly, gpg is fine or something else automated.
2. **With keeping security first in mind, no plain-text for any authentication methods.** I don't want password files, I don't want things running as root as much as possible, create additional svc accounts or users to manage as
part of the deployment/setup method.
3. **Current Infrastructure in Place** I have 72 cpus on this host and  currently only utilizing about 7% right now on a high end but mostly around 4-5% 256gigs of ram with about 27% utilization. For storage I have 1 fast pool with
4 TB usable and currently 8.5% utilization and 1 slow pool with about 78 tb usable and currrently 6% utilization. This is all on Proxmox Ve version #. (This is good to keep updated as when suggesting or building something you can keep from overprovisioning in theory)
4. **Conversation History** Make sure as part of the process of suggestions or creating/setting up that you update/create the conversations.md file and inject current conversation history of what's been done so far.
###
