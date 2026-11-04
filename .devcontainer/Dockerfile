# Development image: Rust (rustup, cargo, clippy) on Debian bookworm.
# Node, Terraform, AWS CLI and Python are added as "features" in devcontainer.json.
FROM mcr.microsoft.com/devcontainers/rust:1-bookworm

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*
