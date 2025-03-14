#!/bin/bash

# Define variables (customize these values)
DOMAIN="docreg.in"  # Replace with your domain
USERNAME="chintanboghara"  # Replace with your desired username
PASSWORD="docreg@@prv"  # Replace with your desired password

# Step 1: Update and upgrade the system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Step 2: Install Docker and Docker Compose
echo "Installing Docker and Docker Compose..."
sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
sudo newgrp docker

# Verify Docker installation
docker --version

# Step 3: Create directories for registry and certificates
echo "Creating necessary directories..."
sudo mkdir -p /etc/docker/registry
sudo mkdir -p /etc/letsencrypt

# Step 4: Install Apache utilities for htpasswd
echo "Installing Apache utilities for authentication..."
sudo apt install -y apache2-utils

# Generate htpasswd file for authentication
echo "Setting up authentication with htpasswd..."
echo "$PASSWORD" | sudo htpasswd -Bbn "$USERNAME" > /etc/docker/registry/htpasswd

# Set proper permissions for htpasswd file
sudo chmod 640 /etc/docker/registry/htpasswd
sudo chown root:docker /etc/docker/registry/htpasswd

# Step 5: Install Certbot for SSL certificates
echo "Installing Certbot for SSL certificates..."
sudo apt install -y certbot

# Generate SSL certificate (ensure your domain is pointed to this server)
echo "Generating SSL certificate with Certbot..."
sudo certbot certonly --standalone -d "$DOMAIN"

# Adjust certificate permissions
sudo chmod -R 755 /etc/letsencrypt/
sudo chmod -R 644 /etc/letsencrypt/live/"$DOMAIN"/*

# Step 6: Run the Docker registry with authentication and SSL
echo "Starting Docker registry container..."
docker run -d -p 5000:5000 --name registry --restart always \
  -v /etc/docker/registry:/auth \
  -v /etc/letsencrypt:/certs \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Private Docker Registry" \
  -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
  -e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/live/$DOMAIN/fullchain.pem" \
  -e "REGISTRY_HTTP_TLS_KEY=/certs/live/$DOMAIN/privkey.pem" \
  registry:2

# Step 7: Verify the registry is running
echo "Verifying the registry is running..."
docker ps | grep registry

# Step 8: Test the secure connection
echo "Testing secure connection to the registry..."
curl -k -u "$USERNAME:$PASSWORD" https://"$DOMAIN":5000/v2/

# Step 9: Login to the registry
echo "Logging in to the registry..."
docker login "$DOMAIN":5000

# Step 10: Tag and push a sample image
echo "Pushing a sample image to the registry..."
docker pull ubuntu
docker tag ubuntu "$DOMAIN":5000/ubuntu
docker push "$DOMAIN":5000/ubuntu

# Step 11: Verify the image is in the registry
echo "Listing images in the registry..."
curl -k -u "$USERNAME:$PASSWORD" https://"$DOMAIN":5000/v2/_catalog

echo "Private Docker registry setup completed!"
