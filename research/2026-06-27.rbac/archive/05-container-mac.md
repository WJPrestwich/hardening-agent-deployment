# E. Container and host-level MAC

- **AppArmor** works on Ubuntu/Debian with Docker out-of-the-box. Generate
  profiles with `aa-genprof`/`aa-logprof`, apply with
  `--security-opt apparmor=<profile>`. Important: the 2026 “CrackArmor”
  vulnerabilities show AppArmor profile loading can be attacked; keep kernels
  patched.
- **SELinux** is default on RHEL/Fedora. Use Udica to generate container
  policies, `audit2allow` for tuning, and `:z`/`:Z` volume relabeling.
- **Landlock / seccomp / user namespaces** were not well covered by the
  research; primary docs (kernel.org, libseccomp, Docker/Podman) are the next
  step for concrete examples.
- **Rootless Docker vs. rootless Podman** also needs primary docs; rootless
  Podman can pass GPU device nodes with `--device` or CDI.

## Sources

- Docker AppArmor docs
- Google Container-Optimized OS AppArmor guide
- Red Hat SELinux container policy docs
- Udica FOSDEM slides
- container-selinux man page
- CSA / Qualys CrackArmor advisories
