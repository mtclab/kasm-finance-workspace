# Kasm Finance Workspace

Financial analysis & data science workspace with OpenBB Platform, Jupyter Lab, and full Python data stack on Ubuntu 24.04 desktop.

## What's Included

| Component | Version | Notes |
|-----------|---------|-------|
| Base image | `kasmweb/ubuntu-noble-desktop:1.18.0-rolling-weekly` | Ubuntu 24.04 + XFCE + Chrome |
| OpenBB Platform | latest | Financial data SDK + CLI |
| OpenBB CLI | 1.4.1 | Interactive terminal |
| OpenBB Charting | 2.x (pinned <3) | Compatible `create_backend` API |
| pywry | 0.6.x (pinned <0.7) | Chart popup rendering via webkit2gtk-4.0 |
| webkit2gtk-4.0 | from Ubuntu 22.04 (jammy) | Required by pywry for browser chart windows |
| Jupyter Lab | latest | Notebooks on port 8888 |
| Python | 3.12 | System python3 |
| Node.js | 22 LTS | For Playwright MCP |
| OpenCode | latest (mtclab fork) | Terminal AI coding agent |
| Database clients | psql, sqlite3, redis-cli | PostgreSQL, SQLite, Redis |
| gh (GitHub CLI) | latest | Git operations |

### Python Packages (`/opt/finance/` venv)

`openbb[all]`, `openbb-charting[pywry]>=2.3,<3`, `openbb-cli`, `jupyterlab`, `pandas`, `numpy`, `scipy`, `scikit-learn`, `matplotlib`, `seaborn`, `plotly`, `statsmodels`, `yfinance`, `pandas-datareader`, `fredapi`, `sqlalchemy`, `psycopg2-binary`, `redis`, `httpx`, `pydantic`, `rich`, `ipywidgets`

### Key Fix: webkit2gtk-4.0

Ubuntu 24.04 (Noble) only ships `libwebkit2gtk-4.1`. OpenBB's CLI chart rendering uses `pywry<0.7` which links against `libwebkit2gtk-4.0.so.37` and `libjavascriptcoregtk-4.0.so.18`. We install these from the Ubuntu 22.04 (Jammy) archive alongside the Noble 4.1 libs. Coexistence is fine — they install under different sonames.

## Build & Run

```bash
# Build
docker build -t ghcr.io/mtclab/kasm-finance-workspace:latest .

# Run
docker compose up -d

# Access
# KasmVNC:  https://localhost:6901  (password: password)
# Jupyter:   http://localhost:8888
```

## OpenBB Usage

### CLI (interactive terminal)
Open a terminal in the KasmVNC desktop and run:
```bash
openbb
```
Charts will open in a browser window via pywry.

### SDK (Python / Jupyter)
```python
from openbb import obb

# GDP data
data = obb.economy.gdp.nominal(provider='oecd')

# Equity price history
data = obb.equity.price.historical(symbol="AAPL", provider="yfinance")

# Chart in Jupyter
data = obb.equity.price.historical(symbol="AAPL", provider="yfinance", chart=True)
data.chart.fig.show()
```

## Ports

| Port | Service |
|------|---------|
| 6901 | KasmVNC (HTTPS) |
| 8888 | Jupyter Lab |

## Troubleshooting

### OpenBB CLI ImportError: cannot import name 'create_backend'
`openbb-charting 3.x` removed `create_backend`/`get_backend`. Fix:
```bash
pip install 'openbb-charting>=2.3,<3'
```

### Charts not rendering (pywry crashes)
Ensure `libwebkit2gtk-4.0-37` is installed:
```bash
dpkg -l libwebkit2gtk-4.0-37
```
If missing, the Dockerfile installs it from Ubuntu 22.04 (jammy).

### OECD forecast 404
Known upstream issue — the OECD forecast endpoint is currently broken on their side. Use `nominal` or `real` GDP instead.