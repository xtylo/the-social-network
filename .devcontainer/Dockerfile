# Imagen de desarrollo: Rust (rustup, cargo, clippy) sobre Debian bookworm.
# Node, Terraform, AWS CLI y Python se agregan como "features" en devcontainer.json.
FROM mcr.microsoft.com/devcontainers/rust:1-bookworm

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*
