# Garage S3 Object Storage with WebUI
This project provides a lightweight, self-hosted S3-compatible object storage solution using Garage HQ and a companion WebUI. It is designed to run efficiently in Docker and includes a cross-platform script to handle cluster initialization on both Windows (Git Bash/WSL) and Linux.

---
### 🚀 Quick Start
1. Prerequisites
 - Docker and Docker Compose installed.
 - If using Windows, use Git Bash to run the setup scripts.

2. Deploy Containers
From the project root, run:
```bash
docker compose up -d
```

3. Initialize the Storage Layout

Garage starts in an unconfigured state. You must assign storage capacity to the node before it can accept data. Use the provided cross-platform script:

```bash
chmod +x setup-garage.sh  # Only needed for Linux/macOS
./setup-garage.sh
```

---
## 📂 Project Structure

| File | Description |
| :--- | :--- |
| `compose.yaml` | Defines the Garage and WebUI services. |
| `garage.toml` | The core configuration file for Garage (Network, S3 API, and Admin settings). |
| `setup-garage.sh` | Cross-platform initialization script (fixes Windows path conversion issues). |
| `./data` | Directory where your actual S3 objects are stored (mapped to D: drive for space). |
| `./meta` | Directory for Garage's SQLite metadata database. |

---
## 🌐 Access Points

| Service | URL | Note |
| :--- | :--- | :--- |
| **S3 API** | [https://s3.garage.localhost](https://s3.garage.localhost) | Endpoint for S3 clients (AWS CLI, Cyberduck, etc.) |
| **Web UI** | [https://ui.garage.localhost](https://ui.garage.localhost) | Browser interface for managing buckets and keys |
| **Traefik Dashboard** | [http://localhost:8080](http://localhost:8080) | Monitor routes and SSL certificates |

---
### 📝 Configuration

The `garage.toml` file contains the core configuration for Garage. It is used to define the network, S3 API, and admin settings.

#### How to Generate RPC Secret and Admin Token

```bash
openssl rand -hex 32
```

```toml
[global]
rpc_secret = "your_rpc_secret"
admin_token = "your_admin_token"
```

Actual garage.toml file looks like this:

```toml
replication_factor = 1

metadata_dir = "/var/lib/garage/meta"
data_dir = "/var/lib/garage/data"
db_engine = "sqlite"

# Core Network Settings (Do NOT use brackets here)
rpc_bind_addr = "[::]:3901"
rpc_public_addr = "localhost:3901"
rpc_secret = "7d44866f54c2ca1020275815682c61146747120a27361734a667102e3c035361"

[s3_api]
s3_region = "garage"
api_bind_addr = "[::]:3900"
root_domain = ".s3.garage.localhost"

[s3_web]
bind_addr = "[::]:3902"
root_domain = ".web.garage.localhost"
index = "index.html"

[admin]
api_bind_addr = "[::]:3903"
admin_token = "6cd708160b880db78699c54ee8a25ba162a11835239d3923f7c3f82a7d8d43a3"
``` 

### Explaination of garage.toml file

```toml
replication_factor = 1
```

This line defines the number of copies of data that Garage will maintain. In this case, it's set to 1, meaning each piece of data is stored once.

```toml
metadata_dir = "/var/lib/garage/meta"
data_dir = "/var/lib/garage/data"
db_engine = "sqlite"
```

These lines specify where Garage will store its metadata and data. The metadata_dir is where the SQLite database is stored, and data_dir is where the actual S3 objects are stored.

```toml
rpc_bind_addr = "[::]:3901"
rpc_public_addr = "localhost:3901"
rpc_secret = "7d44866f54c2ca1020275815682c61146747120a27361734a667102e3c035361"
```

These lines define the network settings for the Garage node. rpc_bind_addr is the address that Garage will listen on for internal communication, rpc_public_addr is the address that Garage will use to communicate with clients, and rpc_secret is the secret key used for authentication.

```toml
[s3_api]
s3_region = "garage"
api_bind_addr = "[::]:3900"
root_domain = ".s3.garage.localhost"
```

These lines define the S3 API settings. s3_region is the region that Garage will use for S3 objects, api_bind_addr is the address that Garage will listen on for S3 API requests, and root_domain is the domain that Garage will use for S3 objects.

```toml
[s3_web]
bind_addr = "[::]:3902"
root_domain = ".web.garage.localhost"
index = "index.html"
```

These lines define the S3 web settings. bind_addr is the address that Garage will listen on for S3 web requests, root_domain is the domain that Garage will use for S3 web objects, and index is the default file to serve when a directory is requested.

```toml
[admin]
api_bind_addr = "[::]:3903"
admin_token = "6cd708160b880db78699c54ee8a25ba162a11835239d3923f7c3f82a7d8d43a3"
```

These lines define the admin API settings. api_bind_addr is the address that Garage will listen on for admin API requests, and admin_token is the token used for authentication.

---
### Docker Compose

The `compose.yaml` file defines the Traefik, Garage, and WebUI services. Traefik acts as a reverse proxy handling SSL termination and routing.

```yaml
services:
  traefik:
    image: traefik:v3.6.6
    container_name: traefik_container
    hostname: chetan-traefik
    restart: unless-stopped
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      # Define Entrypoints
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      # Global Redirect HTTP -> HTTPS
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      # Enable File Provider for SSL Certs
      - "--providers.file.filename=/etc/traefik/traefik-dynamic.yaml"

    ports:
      - "80:80" # HTTP traffic
      - "443:443" # HTTPS traffic
      - "8080:8080" # Traefik Dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./certs:/etc/traefik/certs:ro
      - ./traefik-dynamic.yaml:/etc/traefik/traefik-dynamic.yaml:ro

  garage:
    image: dxflrs/garage:090dbb412aff0afcbd42183ec12fa62c15bde58b
    container_name: garage_container
    hostname: chetan-garage
    restart: unless-stopped
    # Using -c to ensure it picks up your mapped config
    command: /garage -c /etc/garage.toml server
    env_file:
      - .env # Load environment variables from .env file (only MSYS_NO_PATHCONV=1 env is required)
    ports:
      - "3901:3901" # Keep RPC open for clustering
    volumes:
      - ./garage.toml:/etc/garage.toml:ro
      - ${METADATA_DIR}:/var/lib/garage/meta
      - ${DATA_DIR}:/var/lib/garage/data
    labels:
      - "traefik.enable=true"
      # S3 API Router
      - "traefik.http.routers.garage-s3.rule=HostRegexp(`{subdomain:[a-z0-9-]+}.${S3_SUBDOMAIN}`) || Host(`${S3_SUBDOMAIN}`)"
      - "traefik.http.routers.garage-s3.entrypoints=websecure"
      - "traefik.http.routers.garage-s3.service=garage-s3-svc"
      - "traefik.http.services.garage-s3-svc.loadbalancer.server.port=3900"
      # S3 API Router (HTTPS)
      - "traefik.http.routers.garage-s3.tls=true"

  webui:
    image: khairul169/garage-webui:1.1.0
    container_name: garage-webui_container
    hostname: chetan-webui
    restart: unless-stopped
    depends_on:
      - garage
    extra_hosts:
      - "${S3_SUBDOMAIN}:host-gateway"
    env_file:
      - .env # Load environment variables from .env file (# Garage WebUI section Env required)
    volumes:
      # Alpine Linux looks here for trusted CA certificates
      - ./certs/rootCA.crt:/etc/ssl/certs/rootCA.pem:ro
      - ./certs/rootCA.crt:/usr/local/share/ca-certificates/rootCA.crt:ro
      - ./garage.toml:/etc/garage.toml:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.garage-ui.rule=Host(`${WEBUI_SUBDOMAIN}`)"
      - "traefik.http.routers.garage-ui.entrypoints=websecure"
      - "traefik.http.routers.garage-ui.tls=true"
      - "traefik.http.services.garage-ui-svc.loadbalancer.server.port=3909"

```

#### Explaination of Docker Compose File

```yaml
services:
  traefik:
    image: traefik:v3.6.6
    ports:
      - "80:80"
      - "443:443"
```

This part defines the **Traefik** service, which handles SSL termination and routes traffic to the correct containers based on the hostname used in the request.

```yaml
  garage:
    image: dxflrs/garage:090dbb412aff0afcbd42183ec12fa62c15bde58b
    labels:
      - "traefik.http.routers.garage-s3.rule=HostRegexp(`{subdomain:[a-z0-9-]+}.${S3_SUBDOMAIN}`) || Host(`${S3_SUBDOMAIN}`)"
      - "traefik.http.routers.garage-s3.tls=true"
```

This part of the `compose.yaml` file defines the **Garage** service. Instead of exposing ports directly, it uses Traefik labels to define routing rules for S3 API traffic (both top-level and bucket subdomains) with TLS enabled.

```yaml
  webui:
    image: khairul169/garage-webui:1.1.0
    labels:
      - "traefik.http.routers.garage-ui.rule=Host(`${WEBUI_SUBDOMAIN}`)"
      - "traefik.http.routers.garage-ui.tls=true"
```

This part defines the **WebUI** service, which is also routed via Traefik. It provides the browser interface at `https://ui.garage.localhost`.

---
### 🔐 SSL/HTTPS Configuration

This project uses Traefik to provide HTTPS. You can either use a self-signed certificate for local development or provide your own certificates.

#### 1. Generate a Self-Signed Certificate
If you don't have a certificate, you can generate one using `openssl` (run this from the project root):

```bash
# Create the certs directory if it doesn't exist
mkdir -p certs

# Generate a self-signed certificate and private key
openssl req -x509 -newkey rsa:4096 -keyout certs/local-key.pem -out certs/local-cert.pem -sha256 -days 3650 -nodes -subj "/CN=*.garage.localhost"
```

#### 2. Add Existing Certificates
If you have existing certificates, place them in the `certs/` directory and ensure the filenames match those in `traefik-dynamic.yaml`:

```yaml
# traefik-dynamic.yaml
tls:
  certificates:
    - certFile: "/etc/traefik/certs/local-cert.pem"
      keyFile: "/etc/traefik/certs/local-key.pem"
```

#### 3. Trusting the Certificate (Local Development)
For the WebUI to communicate securely with the S3 API via Traefik, it needs to trust the certificate. If you are using a custom Root CA, place it at `certs/rootCA.crt`. The containers are configured to load this from the `./certs` volume.

---
### 🛠 Troubleshooting

#### "Layout not ready" (Error 500)
This occurs if the `setup-garage.sh` script hasn't been run or failed. Garage will not function until a node is assigned a capacity and the layout version is applied.

#### Windows Path Issues
If you manually run `docker exec` commands in Git Bash and see errors like `C:/Program Files/Git/garage: no such file`, it is due to POSIX path conversion.

Fix: Prefix your commands with `MSYS_NO_PATHCONV=1` or use double slashes (e.g., `//garage`).

#### Disk Space
The current configuration is set to store data in the project folder. To save space on your `C:` drive, ensure this project folder is located on your `D:` drive. The `setup-garage.sh` script is configured to assign 10G of virtual capacity by default.

---
### 🔐 Security Note
RPC Secret: The `rpc_secret` in `garage.toml` is used for cluster communication.

Admin Token: The `admin_token` in `garage.toml` must match the `API_ADMIN_KEY` in `compose.yaml` for the WebUI to function.