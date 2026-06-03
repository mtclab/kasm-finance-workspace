FROM kasmweb/ubuntu-noble-desktop:1.18.0-rolling-weekly

# ──────────────────────────────────────────────────────────────
# Kasm Finance Workspace — OpenBB + data science on desktop
# Base: Ubuntu 24.04 + XFCE + Chrome (kasmweb/ubuntu-noble-desktop)
# Key fix: webkit2gtk-4.0 from Ubuntu 22.04 (jammy) for pywry charts
# ──────────────────────────────────────────────────────────────

USER root
ENV HOME=/home/kasm-default-profile
ENV STARTUPDIR=/dockerstartup
ENV INST_SCRIPTS=$STARTUPDIR/install
WORKDIR $HOME

######### Begin Customizations ###########

# ── System packages ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    pkg-config \
    git \
    git-lfs \
    curl \
    wget \
    jq \
    unzip \
    zip \
    p7zip-full \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    gnupg \
    net-tools \
    dnsutils \
    openssh-client \
    fd-find \
    ripgrep \
    fzf \
    postgresql-client \
    sqlite3 \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*

# ── webkit2gtk-4.0 (jammy) for pywry chart rendering ─────────
# Ubuntu 24.04 only ships webkit2gtk-4.1 but pywry<0.7 links against 4.0.
# Install the jammy packages alongside the noble 4.1 libs.
RUN echo "deb http://archive.ubuntu.com/ubuntu/ jammy main universe" > /etc/apt/sources.list.d/jammy-webkit.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        libwebkit2gtk-4.0-37 \
        libjavascriptcoregtk-4.0-18 \
    && rm /etc/apt/sources.list.d/jammy-webkit.list \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 22 LTS ────────────────────────────────────────────
RUN curl -fsSL "https://deb.nodesource.com/setup_22.x" | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm config set prefix /usr/local \
    && npm install -g \
        @playwright/mcp@latest

# ── uv (fast Python package manager) ─────────────────────────
ARG UV_VERSION=0.11.14
RUN curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
    | tar xz -C /tmp \
    && mv /tmp/uv-x86_64-unknown-linux-gnu/uv /usr/local/bin/uv \
    && mv /tmp/uv-x86_64-unknown-linux-gnu/uvx /usr/local/bin/uvx \
    && rm -rf /tmp/uv-x86_64-unknown-linux-gnu

# ── yq (YAML processor) ───────────────────────────────────────
ARG YQ_VERSION=v4.53.2
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
    -o /usr/bin/yq && chmod +x /usr/bin/yq

# ── GitHub CLI ────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# ── Python finance venv (OpenBB + data science) ──────────────
# /opt/finance/bin added to PATH via ENV and environment file.
# openbb-charting[pywry] → pywry<0.7 needs webkit2gtk-4.0 (installed above).
# openbb-charting pinned <3 for CLI compatibility (3.0 removes create_backend).
ENV PATH="/home/kasm-user/.npm-global/bin:/opt/finance/bin:${PATH}"
RUN python3 -m venv /opt/finance \
    && /opt/finance/bin/pip install --no-cache-dir \
        'openbb[all]' \
        'openbb-charting[pywry]>=2.3,<3' \
        'openbb-cli' \
        jupyterlab \
        notebook \
        ipywidgets \
        pandas \
        numpy \
        scipy \
        scikit-learn \
        matplotlib \
        seaborn \
        plotly \
        statsmodels \
        yfinance \
        pandas-datareader \
        fredapi \
        sqlalchemy \
        psycopg2-binary \
        redis \
        httpx \
        pydantic \
        rich \
    && /opt/finance/bin/openbb --help > /dev/null 2>&1 || true

# ── Jupyter Lab desktop entry ────────────────────────────────
RUN mkdir -p /usr/share/applications \
    && cat > /usr/share/applications/jupyter-lab.desktop << 'EOF'
[Desktop Entry]
Name=Jupyter Lab
Comment=Jupyter Lab Notebook Environment
Exec=/opt/finance/bin/jupyter lab --no-browser --ip=0.0.0.0 --port=8888 --NotebookApp.token='' --root-dir=/home/kasm-user
Icon=utilities-terminal
Terminal=true
Type=Application
Categories=Development;DataScience;
EOF

# ── OpenBB CLI desktop entry ──────────────────────────────────
RUN mkdir -p /usr/share/applications \
    && cat > /usr/share/applications/openbb.desktop << 'EOF'
[Desktop Entry]
Name=OpenBB Terminal
Comment=OpenBB Financial Data Platform CLI
Exec=/bin/bash -c 'source /opt/finance/bin/activate && openbb'
Icon=utilities-terminal
Terminal=true
Type=Application
Categories=Finance;DataScience;
EOF

# ── OpenCode (terminal AI coding agent) ──────────────────────
RUN curl -fsSL "https://github.com/mtclab/opencode/releases/download/latest/opencode-linux-x64.tar.gz" \
    -o /tmp/opencode.tar.gz \
    && mkdir -p /tmp/opencode-extract \
    && tar xzf /tmp/opencode.tar.gz -C /tmp/opencode-extract \
    && mv /tmp/opencode-extract/bin/opencode /usr/local/bin/opencode \
    && chmod +x /usr/local/bin/opencode \
    && rm -rf /tmp/opencode.tar.gz /tmp/opencode-extract

# ── OpenCode config ──────────────────────────────────────────
RUN mkdir -p $HOME/.config/opencode/skills \
    && mkdir -p $HOME/.config/opencode/agents
COPY ./config/opencode/opencode.json $HOME/.config/opencode/opencode.json
COPY ./config/opencode/AGENTS.md $HOME/.config/opencode/AGENTS.md
COPY ./config/opencode/agents/ $HOME/.config/opencode/agents/
COPY ./config/opencode/skills/ $HOME/.config/opencode/skills/

# ── npm global prefix for kasm-user ──────────────────────────
RUN mkdir -p /home/kasm-user/.npm-global \
    && npm config --location=user set prefix /home/kasm-user/.npm-global

# ── Environment variables ────────────────────────────────────
COPY ./environment /etc/environment
RUN chmod 644 /etc/environment

######### End Customizations ###########

# ── Kasm post-customization steps (required) ──────────────────
RUN chown 1000:0 $HOME
RUN $STARTUPDIR/set_user_permission.sh $HOME

# ── Custom startup script ────────────────────────────────────
COPY ./kasm_startup.sh /tmp/kasm_finance_startup.sh
RUN cat /tmp/kasm_finance_startup.sh >> $STARTUPDIR/custom_startup.sh \
    && chmod +x $STARTUPDIR/custom_startup.sh \
    && rm /tmp/kasm_finance_startup.sh

ENV HOME=/home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME
RUN mkdir -p /home/kasm-user/repot && chown -R 1000:0 /home/kasm-user/repot

USER 1000
WORKDIR /home/kasm-user/repot