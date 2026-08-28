# Reposotory for packagging Bassacuda server.

Types of packages:

Docker images
- mako production Mako server

Debian packages
- mako contains the Mako runtime, matching mako.zip resources, and an optional
  unprivileged systemd service. Package configuration asks whether to enable
  and start the service. The Mako executable also runs Lua scripts.
- mako-dev contains the matching headers, static library, and pkg-config
  metadata for building C addons.
