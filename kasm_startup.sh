#!/bin/bash
# ── kasm-finance-workspace startup ────────────────────────────
# Runs as kasm-user (uid 1000) after KasmVNC starts

# Start Jupyter Lab
if command -v jupyter &> /dev/null; then
    nohup /opt/finance/bin/jupyter lab \
        --no-browser \
        --ip=0.0.0.0 \
        --port=8888 \
        --NotebookApp.token='' \
        --root-dir=/home/kasm-user \
        > /home/kasm-user/.jupyter/lab.log 2>&1 &
    echo "Jupyter Lab started on http://localhost:8888"
fi

echo "kasm-finance-workspace startup complete"