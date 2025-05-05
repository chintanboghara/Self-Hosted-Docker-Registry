# Private Docker Registry on Debian/Ubuntu

A private Docker registry enables you to securely store and manage container images, offering greater security, performance, and control compared to public registries like Docker Hub.

## Overview
- **Operating System**: Debian or Ubuntu
- **Access**: Private, secured with authentication
- **Storage**: Local or cloud-based
- **Security**: Protected with TLS (SSL certificate)

## Prerequisites
- A Debian/Ubuntu system with `sudo` privileges.
- A registered domain name (e.g., `docreg.in`) pointing to your server’s IP address (required for SSL/TLS).
- Internet access for downloading packages and images.

## Step 1: Install Docker and Dependencies

### 1.1 Update Your System
Keep your system current:
```bash
sudo apt update && sudo apt upgrade -y
```

### 1.2 Install Docker and Docker Compose
Install the required tools:
```bash
sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
```
- `docker.io`: Core Docker engine.
- `docker-compose`: Optional, for multi-container management.
- `systemctl enable --now`: Ensures Docker starts on boot.

### 1.3 Verify Installation
Check Docker is running:
```bash
docker --version
```
- Example output: `Docker version 20.10.7, build f0df350`

## Step 2: Run a Local Docker Registry

### 2.1 Start the Registry
Launch a basic registry:
```bash
docker run -d -p 5000:5000 --name registry --restart always registry:2
```
- `-d`: Runs in detached mode.
- `-p 5000:5000`: Maps host port 5000 to the container.
- `--restart always`: Restarts the container automatically.

### 2.2 Verify It’s Running
Test the registry:
```bash
curl http://localhost:5000/v2/
```
- Expected output: `{}` (indicates the API is accessible).

## Step 3: Push and Pull Images

### 3.1 Pull a Sample Image
Download a test image:
```bash
docker pull ubuntu
```

### 3.2 Tag the Image
Associate it with your registry:
```bash
docker tag ubuntu localhost:5000/ubuntu
```

### 3.3 Push the Image
Upload it to your registry:
```bash
docker push localhost:5000/ubuntu
```

### 3.4 List Images
Check stored images:
```bash
curl http://localhost:5000/v2/_catalog
```
- Expected output: `{"repositories":["ubuntu"]}`

### 3.5 Pull the Image
Test retrieval:
```bash
docker rmi ubuntu
docker pull localhost:5000/ubuntu
```

## Step 4: Secure with Authentication

### 4.1 Create Authentication Credentials

#### Set Up a Directory
Create a directory for auth files:
```bash
sudo mkdir -p /etc/docker/registry
sudo chmod 755 /etc/docker/registry
```
- `755`: Owner can read/write/execute; others can read/execute, ensuring accessibility without compromising security.

#### Install `htpasswd`
Add the necessary tool:
```bash
sudo apt update
sudo apt install -y apache2-utils
```

#### Generate Credentials
Create a username/password pair:
```bash
htpasswd -Bbn <username> <password> > /etc/docker/registry/htpasswd
```
- Replace `<username>` and `<password>` (e.g., `user1`, `securepass`).
- `-B`: Uses bcrypt encryption.
- `-n`: Outputs directly to the file.

#### Secure the File
Set permissions:
```bash
sudo chmod 640 /etc/docker/registry/htpasswd
sudo chown root:docker /etc/docker/registry/htpasswd
```
- `640`: Owner can read/write; group (Docker) can read.
- `root:docker`: Ensures Docker can access it securely.

### 4.2 Run Registry with Authentication

#### Stop the Current Registry
Remove the unsecured instance:
```bash
docker stop registry && docker rm registry
```

#### Start with Authentication
Run the secured registry:
```bash
docker run -d -p 5000:5000 --name registry --restart always \
  -v /etc/docker/registry:/auth \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
  registry:2
```

#### Log In
Authenticate:
```bash
docker login localhost:5000
```
- Enter your credentials when prompted.

## Step 5: Secure with SSL/TLS

### 5.1 Install Certbot
Get Certbot for SSL certificates:
```bash
sudo apt install -y certbot
```

### 5.2 Generate an SSL Certificate
Obtain a certificate:
```bash
sudo certbot certonly --standalone -d <your-domain>
```
- Replace `<your-domain>` (e.g., `docreg.in`).
- `--standalone`: Uses port 80 for validation (ensure it’s free).
- Certificates are saved in `/etc/letsencrypt/live/<your-domain>/`.

#### Adjust Permissions
Allow Docker access:
```bash
sudo chmod -R 755 /etc/letsencrypt/
sudo chmod -R 644 /etc/letsencrypt/live/<your-domain>/*
```

### 5.3 Run Registry with SSL

#### Stop the Running Registry
Remove the current instance:
```bash
docker stop registry && docker rm registry
```

#### Start with SSL and Authentication
Launch the fully secured registry:
```bash
docker run -d -p 5000:5000 --name registry --restart always \
  -v /etc/docker/registry:/auth \
  -v /etc/letsencrypt:/certs \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Private Docker Registry" \
  -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
  -e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/live/<your-domain>/fullchain.pem" \
  -e "REGISTRY_HTTP_TLS_KEY=/certs/live/<your-domain>/privkey.pem" \
  registry:2
```
- Replace `<your-domain>`.

#### Test the Connection
Verify HTTPS access:
```bash
curl -k -u <username>:<password> https://<your-domain>:5000/v2/
```
- Expected output: `{}`

#### Log In Securely
Authenticate over HTTPS:
```bash
docker login <your-domain>:5000
```

#### Pull an Image
Test the setup:
```bash
docker pull <your-domain>:5000/ubuntu
```

## Final Checks

1. **Registry Status**  
   Confirm it’s running:
   ```bash
   docker ps | grep registry
   ```

2. **Login Test**  
   Verify authentication:
   ```bash
   docker login <your-domain>:5000
   ```

3. **Catalog Check**  
   List images securely:
   ```bash
   curl -k -u <username>:<password> https://<your-domain>:5000/v2/_catalog
   ```
   - Expected output: `{"repositories":["ubuntu"]}`

## Additional Notes
- **Security**: Use strong passwords and renew certificates with `certbot renew`.
- **Permissions**: Restrict access to sensitive files (`htpasswd`, certificates).
- **Customization**: Adjust settings via environment variables or a config file (see [Docker Registry Docs](https://docs.docker.com/registry/configuration/)).
- **Troubleshooting**: Check DNS, firewall (ports 80/5000), and certificate paths if issues arise.

## Using the Shell Script

A script is provided to automate this setup.

### 1. Customize the Script
Edit these variables:
- `DOMAIN="your-domain.com"` (e.g., `docreg.in`)
- `USERNAME="your-username"` (e.g., `user1`)
- `PASSWORD="your-password"` (strong password)

### 2. Make Executable
```bash
chmod +x self-hosted-docker-registry.sh
```

### 3. Run It
```bash
./self-hosted-docker-registry.sh
```
- The script handles system updates, installations, authentication, SSL setup, and testing.

## Managing Your Registry

Once your private Docker registry is set up, you may need to manage the images stored in it, such as deleting specific images to free up storage space. This section provides instructions on how to delete images and reclaim storage.

### Deleting Images from Your Registry

To delete a specific image from your registry and free up the storage space it occupies, follow these steps. Note that this requires your registry to be configured with persistent storage and deletions enabled. If you set up your registry using the provided script without modifications, you may need to update your setup first.

#### Step 1: Update Your Registry Setup (If Necessary)

If your registry does not already use persistent storage or have deletions enabled, follow these steps to update it:

1. **Stop and remove the current registry container:**
   ```bash
   docker stop registry && docker rm registry
   ```

2. **Create a directory on the host for registry data:**
   ```bash
   sudo mkdir -p /var/lib/docker-registry
   sudo chmod 755 /var/lib/docker-registry
   ```

3. **Relaunch the registry with persistent storage and deletions enabled:**
   Use the following command, replacing `your-domain` with your actual domain:
   ```bash
   docker run -d -p 5000:5000 --name registry --restart always \
     -v /var/lib/docker-registry:/var/lib/registry \
     -v /etc/docker/registry:/auth \
     -v /etc/letsencrypt:/certs \
     -e "REGISTRY_AUTH=htpasswd" \
     -e "REGISTRY_AUTH_HTPASSWD_REALM=Private Docker Registry" \
     -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
     -e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/live/your-domain/fullchain.pem" \
     -e "REGISTRY_HTTP_TLS_KEY=/certs/live/your-domain/privkey.pem" \
     -e "REGISTRY_STORAGE_DELETE_ENABLED=true" \
     registry:2
   ```

   - The `-v /var/lib/docker-registry:/var/lib/registry` option mounts a host directory to persist registry data.
   - The `-e "REGISTRY_STORAGE_DELETE_ENABLED=true"` option enables image deletions.

#### Step 2: Delete a Specific Image

Use the registry's API to delete the image. Replace `your-domain`, `username`, and `password` with your actual values.

1. **List available repositories:**
   ```bash
   curl -k -u username:password https://your-domain:5000/v2/_catalog
   ```
   - Example output: `{"repositories":["ubuntu"]}`

2. **List tags for the repository you want to delete:**
   ```bash
   curl -k -u username:password https://your-domain:5000/v2/ubuntu/tags/list
   ```
   - Example output: `{"name":"ubuntu","tags":["latest"]}`

3. **Get the digest of the image tag:**
   ```bash
   curl -k -u username:password -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
     https://your-domain:5000/v2/ubuntu/manifests/latest
   ```
   - Look for the `Docker-Content-Digest` header in the response, e.g., `Docker-Content-Digest: sha256:abcd1234...`

4. **Delete the image manifest using the digest:**
   ```bash
   curl -k -u username:password -X DELETE \
     https://your-domain:5000/v2/ubuntu/manifests/sha256:abcd1234...
   ```
   - Replace `sha256:abcd1234...` with the actual digest.

#### Step 3: Run Garbage Collection

After deleting the image reference, run garbage collection to free up the storage space:

1. **Stop the registry container:**
   ```bash
   docker stop registry
   ```

2. **Run the garbage collection command:**
   ```bash
   docker run --rm -v /var/lib/docker-registry:/var/lib/registry registry:2 garbage-collect /etc/docker/registry/config.yml
   ```
   - This command removes unreferenced data from the registry storage.

3. **Restart the registry container:**
   ```bash
   docker start registry
   ```

#### Step 4: Verify Deletion and Space Reclamation

1. **Confirm the image is no longer listed:**
   ```bash
   curl -k -u username:password https://your-domain:5000/v2/_catalog
   ```
   - The deleted repository or tag should not appear.

2. **Check the storage usage on the host:**
   ```bash
   du -sh /var/lib/docker-registry
   ```
   - The size should be reduced after garbage collection.

### Alternative: Delete All Images

If you want to delete all images and start with an empty registry, you can remove the registry container and its data:

1. **Stop and remove the registry container:**
   ```bash
   docker stop registry && docker rm registry
   ```

2. **If using persistent storage, delete the data directory:**
   ```bash
   sudo rm -rf /var/lib/docker-registry
   ```

3. **Clean up unused Docker data:**
   ```bash
   docker system prune -f
   ```

4. **Relaunch the registry as needed using the setup script or command.**

**Warning:** This action is destructive and will remove all images from your registry.
