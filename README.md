# Private Docker Registry on Debian/Ubuntu

A private Docker registry allows you to store and manage container images privately, offering enhanced security, performance, and control over your images compared to using public registries like Docker Hub.

## Overview
- **Operating System**: Debian/Ubuntu
- **Registry Access**: Private (secured with authentication)
- **Storage Location**: Local or Cloud
- **Security**: Secured with TLS (SSL certificate)

## Prerequisites
- A Debian/Ubuntu system with sudo privileges.
- A registered domain name (e.g., `docreg.in`) pointing to your server's IP address (required for SSL/TLS).
- Internet access for downloading packages and images.

## Step 1: Install Docker and Dependencies

### 1.1 Update Your System
Ensure your package list and installed packages are up-to-date:
```bash
sudo apt update && sudo apt upgrade -y
```

### 1.2 Install Docker and Docker Compose
Install Docker and Docker Compose for managing containers:
```bash
sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
```
- `docker.io`: The Docker engine.
- `docker-compose`: Useful for managing multi-container setups (optional for this guide).
- `systemctl enable --now`: Starts Docker and enables it on boot.

### 1.3 Verify Docker Installation
Confirm Docker is installed and running:
```bash
docker --version
```
- Example output: `Docker version 20.10.7, build f0df350`

## Step 2: Run a Local Docker Registry

### 2.1 Start the Registry
Launch a basic Docker registry using the official `registry:2` image:
```bash
docker run -d -p 5000:5000 --name registry --restart always registry:2
```
- `-d`: Runs the container in the background.
- `-p 5000:5000`: Maps port 5000 on the host to the container.
- `--restart always`: Automatically restarts the container if it stops.

### 2.2 Verify the Registry is Running
Check if the registry is operational:
```bash
curl http://localhost:5000/v2/
```
- Expected output: `{}`
- This confirms the registry API is accessible.

## Step 3: Push and Pull an Image to the Private Registry

### 3.1 Pull a Sample Image
Download a test image from Docker Hub:
```bash
docker pull ubuntu
```

### 3.2 Tag the Image for the Private Registry
Tag the image to associate it with your local registry:
```bash
docker tag ubuntu localhost:5000/ubuntu
```

### 3.3 Push the Image to the Registry
Upload the tagged image to your registry:
```bash
docker push localhost:5000/ubuntu
```

### 3.4 Check Available Images in the Registry
List all images stored in the registry:
```bash
curl http://localhost:5000/v2/_catalog
```
- Expected output: `{"repositories":["ubuntu"]}`

### 3.5 Pull the Image from the Registry
Test pulling the image back from the registry:
```bash
docker rmi ubuntu
docker pull localhost:5000/ubuntu
```
- `docker rmi`: Removes the local image to simulate a fresh pull.

## Step 4: Secure the Registry with Authentication

### 4.1 Create Authentication Credentials

#### Create a Directory for Authentication Files
Set up a directory to store authentication files:
```bash
sudo mkdir -p /etc/docker/registry
sudo chmod 755 /etc/docker/registry
```
- `755`: Restricts write access to the owner while allowing read/execute for others.

#### Install Apache Utilities (htpasswd)
Install the `htpasswd` tool for creating credentials:
```bash
sudo apt update
sudo apt install -y apache2-utils
```

#### Generate Credentials
Create a username and password pair:
```bash
htpasswd -Bbn <username> <password> > /etc/docker/registry/htpasswd
```
- Replace `<username>` and `<password>` with your desired credentials (e.g., `chintanboghara` and a strong password).
- `-B`: Uses bcrypt for secure encryption.
- `-n`: Outputs credentials instead of prompting for a file.
- **Security Note**: Avoid hardcoding passwords in scripts; run `htpasswd` interactively if preferred.

#### Set Proper Permissions
Secure the `htpasswd` file:
```bash
sudo chmod 640 /etc/docker/registry/htpasswd
sudo chown root:docker /etc/docker/registry/htpasswd
```
- `640`: Read/write for owner, read-only for group.
- `root:docker`: Ensures Docker can access the file.

### 4.2 Run Registry with Authentication

#### Stop the Current Registry
Remove the unsecured registry instance:
```bash
docker stop registry && docker rm registry
```

#### Run a New Instance with Authentication
Start the registry with authentication enabled:
```bash
docker run -d -p 5000:5000 --name registry --restart always \
  -v /etc/docker/registry:/auth \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
  registry:2
```
- `-v /etc/docker/registry:/auth`: Mounts the authentication directory.
- `REGISTRY_AUTH=htpasswd`: Enables password authentication.

#### Login to the Private Registry
Authenticate with the registry:
```bash
docker login localhost:5000
```
- Enter your username and password when prompted.

## Step 5: Secure the Registry with SSL/TLS

### 5.1 Install Certbot for SSL Certificates
Install Certbot to obtain free SSL certificates from Let’s Encrypt:
```bash
sudo apt install -y certbot
```

### 5.2 Generate an SSL Certificate
Generate a certificate for your domain:
```bash
sudo certbot certonly --standalone -d <your-domain>
```
- Replace `<your-domain>` with your domain (e.g., `docreg.in`).
- `--standalone`: Runs a temporary web server for validation.
- **Note**: Ensure your domain resolves to your server’s IP and port 80 is open.

Certificates are stored in `/etc/letsencrypt/live/<your-domain>/`.

#### Adjust Certificate Permissions
Ensure Docker can read the certificates:
```bash
sudo chmod -R 755 /etc/letsencrypt/
sudo chmod -R 644 /etc/letsencrypt/live/<your-domain>/*
```
- Replace `<your-domain>` with your domain.

### 5.3 Run Registry with SSL

#### Stop the Running Registry
Remove the existing registry instance:
```bash
docker stop registry && docker rm registry
```

#### Run the Registry with SSL & Authentication
Start the registry with both SSL and authentication:
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
- Replace `<your-domain>` with your domain.
- `-v /etc/letsencrypt:/certs`: Mounts SSL certificates.
- `REGISTRY_HTTP_TLS_*`: Specifies the certificate and key paths.

#### Test Secure Connection
Verify the registry is accessible over HTTPS:
```bash
curl -k -u <username>:<password> https://<your-domain>:5000/v2/
```
- Replace `<username>`, `<password>`, and `<your-domain>` with your values.
- `-k`: Ignores SSL verification (for testing only).
- Expected output: `{}`

#### Login Securely to the Registry
Log in using HTTPS:
```bash
docker login <your-domain>:5000
```
- Use your username and password.

#### Pull Images from the Secure Registry
Test pulling an image:
```bash
docker pull <your-domain>:5000/ubuntu
```

## Final Checks

### 1. Ensure the Registry is Running
Verify the container is active:
```bash
docker ps | grep registry
```

### 2. Verify Login Works
Test authentication:
```bash
docker login <your-domain>:5000
```

### 3. Check Registry Catalog
List available images securely:
```bash
curl -k -u <username>:<password> https://<your-domain>:5000/v2/_catalog
```
- Expected output: `{"repositories":["ubuntu"]}`

## Additional Notes
- **Security**: Use strong passwords and renew SSL certificates periodically (e.g., with `certbot renew`).
- **Permissions**: Sensitive files (`htpasswd`, SSL certificates) should have restricted access.
- **Configuration**: Customize the registry further using environment variables or a config file (see [Docker Registry Docs](https://docs.docker.com/registry/configuration/)).
- **Troubleshooting**: If SSL fails, check domain DNS settings, firewall rules (ports 80/5000), and certificate paths.

## Running the Shell Script

To automate the setup process, a shell script is provided.

### 1. Customize Variables
Edit the script to replace placeholders with your actual values:
- `DOMAIN="your-domain.com"` (e.g., `docreg.in`)
- `USERNAME="your-username"` (e.g., `chintanboghara`)
- `PASSWORD="your-password"` (e.g., a strong password)

### 2. Make the Script Executable
```bash
chmod +x self-hosted-docker-registry.sh
```

### 3. Run the Script
```bash
./self-hosted-docker-registry.sh
```

The script will:
- Update the system.
- Install Docker and dependencies.
- Set up authentication with `htpasswd`.
- Generate SSL certificates with Certbot.
- Start the Docker registry container with authentication and SSL.
- Test the setup by pushing and pulling a sample image.
