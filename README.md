# Self‑Hosted Docker Registry

A turnkey solution for running a private Docker registry on your own infrastructure, complete with:

- **HTTPS** (self‑signed TLS or real certificates)  
- **HTTP Basic Authentication**  
- **Docker Compose** for easy orchestration  
- **Idempotent Bash script** (`setup-registry.sh`) to automate setup  
- **Environment‑driven configuration** via `.env` file  

## Features & Benefits

1. **Secure by Default**  
   - TLS encryption for all communications  
   - Basic auth to restrict access  

2. **Idempotent Automation**  
   - Re‑run the setup script safely (won’t overwrite existing certs or auth files)  
   - Clear, user‑friendly help text and error messages  

3. **Modular & Extensible**  
   - Docker Compose for multi‑service setups  
   - Easily swap in Let’s Encrypt or custom CA certs  
   - Volumes mount into local directories (`data/`, `certs/`, `auth/`)  

4. **Easy Maintenance**  
   - `.gitignore` excludes sensitive/runtime files  
   - Well‑documented directory structure  
   - Suggestions for CI/CD and certificate renewal  

## Repository Layout

```

Self-Hosted-Docker-Registry/
│
├── setup-registry.sh       # Idempotent, documented Bash installer
├── registry.env            # DOMAIN, USERNAME, PASSWORD
├── docker-compose.yml      # Compose file for Registry container
├── auth/                   # HTTP auth data (htpasswd)
├── certs/                  # TLS certificates
├── data/                   # Registry storage (images, metadata)
├── .gitignore              # Exclude auth, certs, data
└── README.md               # You are here!

````

## Prerequisites

- **Host OS**: Linux (Ubuntu, Debian, CentOS, etc.)  
- **Docker**: ≥ 20.10 (with `docker compose` plugin)  
- **OpenSSL**: for self‑signed cert generation  
- **Git**: to clone this repo  
- **(Optional)** Certbot & cron/systemd, for Let’s Encrypt integration  

## Configuration

1. **Clone the repo**  
   ```bash
   git clone https://github.com/chintanboghara/Self-Hosted-Docker-Registry.git
   cd Self-Hosted-Docker-Registry
   ````

2. **Edit `registry.env`**
   Rename or copy the template, then set your values:

   ```dotenv
   # registry.env
   DOMAIN=registry.example.com       # FQDN for your registry
   USERNAME=admin                    # Basic auth username
   PASSWORD=strongpassword123        # Basic auth password
   ```

3. **Make the script executable**

   ```bash
   chmod +x setup-registry.sh
   ```

##  Quick Start

Run the installation script. It will:

* Validate your environment variables
* Create `certs/`, `auth/`, `data/` directories
* Generate a self‑signed TLS certificate (if needed)
* Generate an `htpasswd` file with your credentials (if needed)
* Launch the registry via Docker Compose

```bash
./setup-registry.sh
```

**Success message**:

```
Registry running at https://registry.example.com
```

## How It Works

### 1. `setup-registry.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
```

* **`usage()`**: Prints help (`--help` flag)
* **`load_env()`**: Sources `registry.env`, checks for `DOMAIN`, `USERNAME`, `PASSWORD`
* **`prepare_dirs()`**: Creates `certs/`, `auth/`, `data/` if missing
* **`generate_cert()`**:

  * If `certs/fullchain.pem` & `certs/privkey.pem` are absent, calls `openssl req …`
  * Otherwise: prints “already exists”
* **`generate_auth()`**:

  * If `auth/htpasswd` is absent, runs `docker run --rm httpd:2.4 htpasswd -Bbn …`
  * Otherwise: prints “already exists”
* **`run_compose()`**: Executes `docker compose up -d`

### 2. `docker-compose.yml`

```yaml
version: '3.7'
services:
  registry:
    image: registry:2
    restart: always
    ports:
      - "443:5000"
    environment:
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/fullchain.pem
      REGISTRY_HTTP_TLS_KEY: /certs/privkey.pem
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: "Registry Realm"
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
    volumes:
      - ./data:/var/lib/registry
      - ./certs:/certs:ro
      - ./auth:/auth:ro
```

* **Ports**: Exposes `5000` inside container on host’s `443`
* **Volumes**:

  * `./data` → persistent image storage
  * `./certs` → TLS (read‑only)
  * `./auth` → htpasswd (read‑only)
* **Env vars**: Configure storage path, TLS files, and basic auth

## Usage Examples

1. **Login**

   ```bash
   docker login https://$DOMAIN
   # Username: admin
   # Password: <your password>
   ```

2. **Push an image**

   ```bash
   docker pull alpine
   docker tag alpine $DOMAIN/my-alpine:latest
   docker push $DOMAIN/my-alpine:latest
   ```

3. **Pull an image**

   ```bash
   docker pull $DOMAIN/my-alpine:latest
   ```

## Certificate Renewal (Let’s Encrypt)

> *Optional*: replace the self‑signed step with real certs from Let’s Encrypt.

1. Install Certbot on your host.
2. In `setup-registry.sh`, replace `generate_cert()` with:

   ```bash
   certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos -m you@example.com
   ln -sf /etc/letsencrypt/live/$DOMAIN/fullchain.pem certs/fullchain.pem
   ln -sf /etc/letsencrypt/live/$DOMAIN/privkey.pem certs/privkey.pem
   ```
3. Set up a cron or `systemd` timer:

   ```cron
   0 3 * * * certbot renew --deploy-hook "/path/to/repo/setup-registry.sh"
   ```

   This renews certs daily at 03:00 and restarts the registry if they’ve changed.
