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
| S3 API | http://localhost:3900 | Endpoint for S3 clients (AWS CLI, Cyberduck, etc.) |
| Web UI | http://localhost:3909 | Browser interface for managing buckets and keys |
| S3 Web | http://localhost:3902 | Used for static website hosting via S3 |
| Admin API | http://localhost:3903 | Internal API used by the Web UI |

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

The `compose.yaml` file defines the Garage and WebUI services. It is used to define the network, S3 API, and admin settings.

```yaml
services:
  garage:
    image: dxflrs/garage:090dbb412aff0afcbd42183ec12fa62c15bde58b
    container_name: garage
    restart: unless-stopped
    # Using -c to ensure it picks up your mapped config
    command: /garage -c /etc/garage.toml server
    ports:
      - "3900:3900"
      - "3901:3901"
      - "3902:3902"
      - "3903:3903"
    volumes:
      - ./garage.toml:/etc/garage.toml:ro
      - ./meta:/var/lib/garage/meta
      - ./data:/var/lib/garage/data

  webui:
    image: khairul169/garage-webui:1.1.0
    container_name: garage-webui
    restart: unless-stopped
    depends_on:
      - garage
    ports:
      - "3909:3909"
    environment:
      - API_BASE_URL=http://garage:3903
      - API_ADMIN_KEY=6cd708160b880db78699c54ee8a25ba162a11835239d3923f7c3f82a7d8d43a3
      - S3_ENDPOINT_URL=http://localhost:3900
      - S3_REGION=garage
```

#### Explaination of Docker Compose File

```yaml
services:
  garage:
    image: dxflrs/garage:090dbb412aff0afcbd42183ec12fa62c15bde58b
    container_name: garage
    restart: unless-stopped
    # Using -c to ensure it picks up your mapped config
    command: /garage -c /etc/garage.toml server
    ports:
      - "3900:3900"
      - "3901:3901"
      - "3902:3902"
      - "3903:3903"
    volumes:
      - ./garage.toml:/etc/garage.toml:ro
      - ./meta:/var/lib/garage/meta
      - ./data:/var/lib/garage/data
```

This part of the compose.yaml file defines the Garage service. It uses the dxflrs/garage image and maps the garage.toml file to the /etc/garage.toml file in the container. It also maps the meta and data directories to the /var/lib/garage/meta and /var/lib/garage/data directories in the container.

```yaml
  webui:
    image: khairul169/garage-webui:1.1.0
    container_name: garage-webui
    restart: unless-stopped
    depends_on:
      - garage
    ports:
      - "3909:3909"
    environment:
      - API_BASE_URL=http://garage:3903
      - API_ADMIN_KEY=6cd708160b880db78699c54ee8a25ba162a11835239d3923f7c3f82a7d8d43a3
      - S3_ENDPOINT_URL=http://localhost:3900
      - S3_REGION=garage
```

This part of the compose.yaml file defines the WebUI service. It uses the khairul169/garage-webui image and maps the garage.toml file to the /etc/garage.toml file in the container. It also maps the meta and data directories to the /var/lib/garage/meta and /var/lib/garage/data directories in the container.

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