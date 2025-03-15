FROM elixir:1.18-slim

# Set hostname
ENV HOSTNAME=GraphOS

# Install required packages including Node.js and npm
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    git \
    curl \
    wget \
    gnupg \
    ca-certificates \
    build-essential \
    inotify-tools \
    tmux \
    sudo \
    nodejs \
    npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create a non-root user
ARG USERNAME=coder
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Ensure npm global binaries are accessible to non-root user
RUN echo 'export PATH=$PATH:/usr/local/bin:$(npm bin -g)' >> /home/$USERNAME/.bashrc \
    && chown $USERNAME:$USERNAME /home/$USERNAME/.bashrc

# Set up environment
WORKDIR /workspace

# Install Hex and Rebar
RUN mix local.hex --force && mix local.rebar --force

# Install any additional dependencies for MCP
RUN mix archive.install hex mix_audit --force

# Setup for MCP server
ENV MIX_ENV=dev
ENV LANG=C.UTF-8

# Create directories for Claude Code authentication
RUN mkdir -p /home/coder/.config/anthropic \
    && mkdir -p /home/coder/.cache/anthropic \
    && chown -R coder:coder /home/coder/.config \
    && chown -R coder:coder /home/coder/.cache

# Add shell initialization to load .env file
COPY env-setup.sh /home/coder/env-setup.sh
RUN chmod +x /home/coder/env-setup.sh && \
    echo 'source /home/coder/env-setup.sh' >> /home/coder/.bashrc

# Set the default user
USER $USERNAME