# 🚀 NGINX Load Balancer - Quick Setup Guide

**⏱️ Setup time: < 30 seconds | Reading time: < 1 minute**

## 📋 Prerequisites

- Linux/macOS system with nginx installed
- `yq` YAML processor: `brew install yq` (macOS) or `sudo apt install yq` (Ubuntu)
- `curl` (usually pre-installed)

## 🛠️ Quick Setup

### 1. Download Required Files
```bash
# Create setup directory
mkdir nginx-loadbalancer && cd nginx-loadbalancer

# Download script
curl -o generate_nginx_config.sh https://raw.githubusercontent.com/buildwithgrove/load-testing/main/generate_nginx_config.sh

# Download template  
curl -o load_balancer_nginx.conf.template https://raw.githubusercontent.com/buildwithgrove/load-testing/main/template.txt

# Download config template
curl -o load_balancer_nginx_config.yaml https://raw.githubusercontent.com/buildwithgrove/load-testing/main/load_balancer_nginx_config.yaml
```

### 2. Configure Your Backend Servers
Edit `load_balancer_nginx_config.yaml`:
```yaml
nginx:
  listen_address: "0.0.0.0"
  listen_port: 3059

backend:
  path: "/v1"
  servers:
    - host: "192.168.1.100"
      port: 8080
    - host: "192.168.1.101" 
      port: 8080
```

### 3. Generate NGINX Configuration
```bash
chmod +x generate_nginx_config.sh
./generate_nginx_config.sh
```

### 4. Deploy to NGINX
**⚠️ CRITICAL: Follow these steps exactly to avoid breaking your nginx:**

```bash
# Test the generated config
sudo nginx -t -c $(pwd)/nginx.conf

# Backup current config
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)

# Deploy new config
sudo cp nginx.conf /etc/nginx/nginx.conf

# Test again
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### 5. Verify Everything Works
```bash
# Check nginx status
sudo systemctl status nginx

# Test load balancer
curl http://localhost:3059/nginx-health
```

## 📁 Files Overview

- `generate_nginx_config.sh` - Script that generates nginx.conf
- `load_balancer_nginx_config.yaml` - Your customizable settings
- `template.txt` - NGINX template (rename to `load_balancer_nginx.conf.template`)
- `nginx.conf` - Generated output file

## ⚡ Performance Features

- **High throughput**: 8192 connections per worker, 200k file descriptors
- **Smart load balancing**: Uses `least_conn` algorithm
- **Health monitoring**: Built-in `/nginx-health` endpoint
- **Fast failover**: 1s timeouts, automatic server retry

## 🆘 Troubleshooting

**Script fails?**
- Install yq: `brew install yq` or `sudo apt install yq`
- Check file permissions: `chmod +x generate_nginx_config.sh`

**NGINX won't start?**
- Test config: `sudo nginx -t`
- Restore backup: `sudo cp /etc/nginx/nginx.conf.backup.* /etc/nginx/nginx.conf`
- Check logs: `sudo tail -f /var/log/nginx/error.log`

**Need help?** Check the [repository](https://github.com/buildwithgrove/load-testing) for more details.

---
**🎯 Result**: High-performance NGINX load balancer distributing traffic across your backend servers with automatic health checks and failover.