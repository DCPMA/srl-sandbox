# srl-sandbox v2 — OCI container image for sandboxed development environments
# Built on Debian Bookworm with dev tools, Node.js, Claude Code, SSH server.
# Used by the `srl-sandbox` CLI with Apple Container (macOS 26+).
#
# Build: container image build -t srl-sandbox:latest .
# Run:   container run --name test -d srl-sandbox:latest

FROM debian:bookworm-slim

# ── Build arguments ──────────────────────────────────────────────────────────
ARG PYTHON_VERSION=3.13.12

# ── System packages ──────────────────────────────────────────────────────────
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git curl wget jq ripgrep fd-find \
        build-essential python3 python3-pip python3-venv \
        unzip zsh tmux htop sudo \
        openssh-server \
        ca-certificates gnupg lsb-release \
        libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
        libffi-dev liblzma-dev && \
    rm -rf /var/lib/apt/lists/*

# ── Python (from source, configurable version) ──────────────────────────────
RUN cd /tmp && \
    curl -fsSL "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz" -o python.tgz && \
    tar xzf python.tgz && \
    cd "Python-${PYTHON_VERSION}" && \
    ./configure --prefix=/usr/local && \
    make -j"$(nproc)" && \
    make altinstall && \
    cd / && rm -rf /tmp/python.tgz /tmp/Python-${PYTHON_VERSION} && \
    PYMAJMIN=$(echo "${PYTHON_VERSION}" | cut -d. -f1,2) && \
    ln -sf "/usr/local/bin/python${PYMAJMIN}" /usr/local/bin/python3 && \
    ln -sf "/usr/local/bin/python${PYMAJMIN}" /usr/local/bin/python && \
    ln -sf "/usr/local/bin/pip${PYMAJMIN}" /usr/local/bin/pip3 && \
    ln -sf "/usr/local/bin/pip${PYMAJMIN}" /usr/local/bin/pip && \
    python3 --version

# ── GitHub CLI ───────────────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli-stable.list && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends gh && \
    rm -rf /var/lib/apt/lists/*

# ── AWS CLI v2 (aarch64) ────────────────────────────────────────────────────
RUN cd /tmp && \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o awscli.zip && \
    unzip -q awscli.zip && \
    ./aws/install && \
    rm -rf awscli.zip aws

# ── Create dev user (passwordless sudo) ─────────────────────────────────────
RUN useradd -m -s /bin/zsh dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/dev && \
    chmod 0440 /etc/sudoers.d/dev

# ── SSH server configuration ────────────────────────────────────────────────
RUN mkdir -p /run/sshd && \
    sed -i 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#\?AllowAgentForwarding.*/AllowAgentForwarding yes/' /etc/ssh/sshd_config && \
    ssh-keygen -A

# ── SSH authorized keys for dev user ────────────────────────────────────────
RUN mkdir -p /home/dev/.ssh && \
    chmod 700 /home/dev/.ssh && \
    touch /home/dev/.ssh/authorized_keys && \
    chmod 600 /home/dev/.ssh/authorized_keys && \
    chown -R dev:dev /home/dev/.ssh

# ── Node.js via nvm (as dev user) ───────────────────────────────────────────
USER dev
WORKDIR /home/dev

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && \
    nvm install 24 && \
    nvm alias default 24

# ── Claude Code ──────────────────────────────────────────────────────────────
RUN export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && \
    npm install -g @anthropic-ai/claude-code

# ── Shell config ─────────────────────────────────────────────────────────────
RUN echo '# NVM' >> ~/.zshrc && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> ~/.zshrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"' >> ~/.zshrc

# ── Entrypoint ───────────────────────────────────────────────────────────────
USER root
EXPOSE 22

# Start SSH daemon in foreground
CMD ["/usr/sbin/sshd", "-D", "-e"]
