#!/bin/bash

# ========================================================
# NGINX CONFIGURATION GENERATOR SCRIPT
# ========================================================
# 
# This script generates nginx.conf from nginx.conf.template and config.yaml
# 
# Requirements:
# • yq (YAML processor) - install with: brew install yq (macOS) or apt install yq (Ubuntu)
# • All files (template, yaml, script) in the same directory
#
# Usage: ./generate-nginx-config.sh
#
# ========================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ========================================================
# CONFIGURATION
# ========================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/load_balancer_nginx.conf.template"
CONFIG_FILE="${SCRIPT_DIR}/load_balancer_nginx_config.yaml"
OUTPUT_FILE="${SCRIPT_DIR}/nginx.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ========================================================
# HELPER FUNCTIONS
# ========================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v yq &> /dev/null; then
        log_error "yq is not installed. Please install it:"
        echo "  • macOS: brew install yq"
        echo "  • Ubuntu/Debian: sudo apt install yq"
        echo "  • CentOS/RHEL: sudo yum install yq"
        echo "  • Or download from: https://github.com/mikefarah/yq"
        exit 1
    fi
    
    log_success "Dependencies check passed"
}

check_files() {
    log_info "Checking required files..."
    
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        log_error "Template file not found: $TEMPLATE_FILE"
        exit 1
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi
    
    log_success "Required files found"
}

validate_yaml() {
    log_info "Validating YAML configuration..."
    
    if ! yq eval '.' "$CONFIG_FILE" > /dev/null 2>&1; then
        log_error "Invalid YAML syntax in $CONFIG_FILE"
        exit 1
    fi
    
    # Check required fields
    local required_fields=(
        ".nginx.listen_address"
        ".nginx.listen_port"
        ".backend.path"
        ".backend.servers"
        ".performance.max_body_size"
        ".performance.connect_timeout"
        ".performance.send_timeout"
        ".performance.read_timeout"
    )
    
    for field in "${required_fields[@]}"; do
        local field_value
        field_value=$(yq eval "${field}" "$CONFIG_FILE" 2>/dev/null)
        if [[ "$field_value" == "null" || -z "$field_value" ]]; then
            log_error "Missing required field: $field"
            exit 1
        fi
    done
    
    # Validate backend servers array is not empty
    local server_count
    server_count=$(yq eval '.backend.servers | length' "$CONFIG_FILE")
    if [[ "$server_count" -eq 0 ]]; then
        log_error "No backend servers defined in .backend.servers"
        exit 1
    fi
    
    log_success "YAML validation passed ($server_count backend servers found)"
}

generate_backend_servers() {
    local backend_servers_config=""
    local server_count
    server_count=$(yq eval '.backend.servers | length' "$CONFIG_FILE")
    
    for ((i=0; i<server_count; i++)); do
        local host port max_fails fail_timeout
        host=$(yq eval ".backend.servers[$i].host" "$CONFIG_FILE")
        port=$(yq eval ".backend.servers[$i].port" "$CONFIG_FILE")
        max_fails=$(yq eval ".backend.servers[$i].max_fails" "$CONFIG_FILE")
        fail_timeout=$(yq eval ".backend.servers[$i].fail_timeout" "$CONFIG_FILE")
        
        backend_servers_config+="        server ${host}:${port} max_fails=${max_fails} fail_timeout=${fail_timeout};"
        if [[ $i -lt $((server_count - 1)) ]]; then
            backend_servers_config+=$'\n'
        fi
    done
    
    echo "$backend_servers_config"
}

generate_nginx_config() {
    log_info "Generating nginx configuration..."
    
    # Extract values from YAML
    local listen_address listen_port backend_path max_body_size
    local connect_timeout send_timeout read_timeout
    
    listen_address=$(yq eval '.nginx.listen_address' "$CONFIG_FILE")
    listen_port=$(yq eval '.nginx.listen_port' "$CONFIG_FILE")
    backend_path=$(yq eval '.backend.path' "$CONFIG_FILE")
    max_body_size=$(yq eval '.performance.max_body_size' "$CONFIG_FILE")
    connect_timeout=$(yq eval '.performance.connect_timeout' "$CONFIG_FILE")
    send_timeout=$(yq eval '.performance.send_timeout' "$CONFIG_FILE")
    read_timeout=$(yq eval '.performance.read_timeout' "$CONFIG_FILE")
    
    # Generate backend servers section
    local backend_servers_section
    backend_servers_section=$(generate_backend_servers)
    
    # Create output file by processing template line by line
    local temp_file
    temp_file=$(mktemp)
    
    # First, perform basic variable substitutions
    sed "s|{{listen_address}}|${listen_address}|g" "$TEMPLATE_FILE" | \
    sed "s|{{listen_port}}|${listen_port}|g" | \
    sed "s|{{backend_path}}|${backend_path}|g" | \
    sed "s|{{max_body_size}}|${max_body_size}|g" | \
    sed "s|{{connect_timeout}}|${connect_timeout}|g" | \
    sed "s|{{send_timeout}}|${send_timeout}|g" | \
    sed "s|{{read_timeout}}|${read_timeout}|g" > "$temp_file"
    
    # Now handle the backend servers template section
    local in_template=false
    
    # Clear and create output file
    echo "" > "$OUTPUT_FILE"
    truncate -s 0 "$OUTPUT_FILE"
    
    while IFS= read -r line; do
        if echo "$line" | grep -q "Backend servers will be generated from config.yaml"; then
            echo "        # Backend servers generated from $(basename "$CONFIG_FILE")" >> "$OUTPUT_FILE"
            echo -n "$backend_servers_section" >> "$OUTPUT_FILE"
            in_template=true
        elif echo "$line" | grep -F "{{/each}}" > /dev/null; then
            in_template=false
        elif [ "$in_template" = false ]; then
            echo "$line" >> "$OUTPUT_FILE"
        fi
    done < "$temp_file"
    
    # Clean up
    rm "$temp_file"
    
    log_success "nginx.conf generated successfully"
}

display_summary() {
    log_info "Configuration Summary:"
    echo "  • Template file: $(basename "$TEMPLATE_FILE")"
    echo "  • Config file: $(basename "$CONFIG_FILE")" 
    echo "  • Output file: $(basename "$OUTPUT_FILE")"
    
    local server_count
    server_count=$(yq eval '.backend.servers | length' "$CONFIG_FILE")
    echo "  • Backend servers: $server_count"
    
    local listen_address listen_port backend_path
    listen_address=$(yq eval '.nginx.listen_address' "$CONFIG_FILE")
    listen_port=$(yq eval '.nginx.listen_port' "$CONFIG_FILE")
    backend_path=$(yq eval '.backend.path' "$CONFIG_FILE")
    
    echo "  • Listen on: ${listen_address}:${listen_port}"
    echo "  • Backend path: $backend_path"
}

display_deployment_instructions() {
    # Extract listen address and port for verification commands
    local listen_address listen_port
    listen_address=$(yq eval '.nginx.listen_address' "$CONFIG_FILE")
    listen_port=$(yq eval '.nginx.listen_port' "$CONFIG_FILE")
    
    echo ""
    echo "========================================================"
    echo "🚀 DEPLOYMENT INSTRUCTIONS"
    echo "========================================================"
    echo ""
    log_warning "IMPORTANT: Follow these exact steps to deploy your nginx configuration:"
    echo ""
    
    echo -e "${YELLOW}1. TEST the generated configuration:${NC}"
    echo "   sudo nginx -t -c $(realpath "$OUTPUT_FILE")"
    echo ""
    
    echo -e "${YELLOW}2. BACKUP your current nginx configuration:${NC}"
    echo "   sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)"
    echo ""
    
    echo -e "${YELLOW}3. COPY the new configuration to nginx directory:${NC}"
    echo "   sudo cp $(realpath "$OUTPUT_FILE") /etc/nginx/nginx.conf"
    echo ""
    
    echo -e "${YELLOW}4. TEST the configuration again after copying:${NC}"
    echo "   sudo nginx -t"
    echo ""
    
    echo -e "${YELLOW}5. RELOAD nginx to apply the new configuration:${NC}"
    echo "   sudo systemctl reload nginx"
    echo "   # OR alternatively: sudo nginx -s reload"
    echo ""
    
    echo -e "${RED}⚠️  CRITICAL SAFETY NOTES:${NC}"
    echo "   • Always test configuration BEFORE copying to /etc/nginx/"
    echo "   • Keep the backup file in case you need to rollback"
    echo "   • If reload fails, restore backup: sudo cp /etc/nginx/nginx.conf.backup.* /etc/nginx/nginx.conf"
    echo "   • Monitor nginx status after reload: sudo systemctl status nginx"
    echo ""
    
    echo -e "${GREEN}✅ VERIFICATION STEPS:${NC}"
    echo "   • Check nginx is running: sudo systemctl status nginx"
    echo "   • Test load balancer endpoint: curl http://${listen_address}:${listen_port}/nginx-health"
    echo "   • Monitor nginx logs: sudo tail -f /var/log/nginx/error.log"
    echo ""
    
    echo "========================================================"
}

# ========================================================
# MAIN EXECUTION
# ========================================================
main() {
    echo "========================================================"
    echo "         NGINX CONFIGURATION GENERATOR"
    echo "========================================================"
    echo ""
    
    check_dependencies
    check_files
    validate_yaml
    generate_nginx_config
    display_summary
    display_deployment_instructions
    
    echo ""
    log_success "Configuration generation completed!"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi