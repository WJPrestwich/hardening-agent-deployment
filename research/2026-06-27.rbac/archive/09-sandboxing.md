# I. Non-RBAC blast-radius controls

- **Sandboxing alternatives**:
  - **gVisor**: supports NVIDIA GPU via `nvproxy`; possible network/I/O
    overhead.
  - **Kata Containers**: GPU passthrough via vfio-pci/QEMU; watch for CVEs.
  - **Firecracker**: no production GPU passthrough yet.
  - **Rootless Podman**: can pass GPU device nodes with `--device` or CDI.
- **Landlock + user namespaces**: allow a process to self-sandbox filesystem
  and (ABI v4) network access without full LSM profiles. Good candidate for a
  custom workspace jail.
- **Canary tokens / honeypots**: plant fake secrets/files to detect
  unauthorized reads; use OpenCanary, Glutton, or Mailoney for network
  honeypots.
- **cgroup v2**: `cpu.max`, `memory.max`, and `io.max` cap resources. Mainstream
  on RHEL 9 / Ubuntu 22.04+.

## Sources

- gVisor GPU docs
- Kata NVIDIA passthrough docs
- Firecracker GPU discussion
- Podman GPU passthrough blog
- Kernel Landlock docs
- Island tool
- NVIDIA canary blog
- OpenCanary / Honeynet Project
- cgroup-v2 kernel docs
