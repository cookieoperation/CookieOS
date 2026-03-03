# Stage 1: Build dependencies and tools
FROM debian:bookworm-slim AS base

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Optimized tool layer with combined dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    xz-utils \
    qemu-utils \
    util-linux \
    parted \
    dosfstools \
    udev \
    mount \
    build-essential \
    python3 \
    file \
    gpg \
    rsync \
    pv \
    bsdextrautils \
    e2fsprogs \
    debootstrap \
    qemu-user-static \
    binfmt-support \
    debian-archive-keyring \
    kpartx \
    ca-certificates \
    python3-requests \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Application build environment (Node.js)
FROM base AS builder
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Default entrypoint for building the image
ENTRYPOINT ["/bin/bash", "./build_image.sh"]

