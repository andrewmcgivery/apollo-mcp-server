# Build stage
FROM rust:1.89.0-bookworm AS builder

WORKDIR /app

# Install build dependencies (matching Nix: perl, pkg-config)
RUN apt-get update && apt-get install -y \
    perl \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy source files (matching Nix source filter: Cargo files, .rs, .graphql, .snap)
COPY Cargo.toml Cargo.lock rust-toolchain.toml ./
COPY crates/ crates/

# Build the release binary
RUN cargo build --release --package apollo-mcp-server --bin apollo-mcp-server

# Runtime stage - minimal image with just glibc (similar to Nix's minimal output)
# Using distroless/cc which includes glibc and CA certificates
FROM gcr.io/distroless/cc-debian12

# Copy the binary
COPY --from=builder /app/target/release/apollo-mcp-server /usr/local/bin/apollo-mcp-server

# Create /data directory (matching Nix's fakeRootCommands: mkdir data && chmod a+r data)
# WORKDIR creates the directory if it doesn't exist
WORKDIR /data

# Environment variables (matching Nix config.Env)
ENV APOLLO_MCP_TRANSPORT__TYPE=streamable_http
ENV APOLLO_MCP_TRANSPORT__ADDRESS=0.0.0.0

# Expose port (matching Nix config.ExposedPorts)
EXPOSE 8000/tcp

# Run as non-root user (matching Nix config.User and config.Group = 1000)
USER 1000:1000

# Entrypoint and Cmd (matching Nix config.Entrypoint and config.Cmd)
ENTRYPOINT ["apollo-mcp-server"]
CMD ["/dev/null"]
