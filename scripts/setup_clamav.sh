#!/bin/bash

# SnapVault ClamAV Setup Script
# This script sets up ClamAV natively on your system (no Docker required)

set -e  # Exit on any error

echo "🦠 Setting up ClamAV for SnapVault..."
echo "=================================="

# Detect operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
else
    echo "❌ Unsupported operating system: $OSTYPE"
    exit 1
fi

echo "📋 Detected OS: $OS"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install ClamAV based on OS
install_clamav() {
    echo "📦 Installing ClamAV..."

    if [[ "$OS" == "macos" ]]; then
        if command_exists brew; then
            brew install clamav
        else
            echo "❌ Homebrew not found. Please install Homebrew first:"
            echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
    elif [[ "$OS" == "linux" ]]; then
        if command_exists apt-get; then
            # Debian/Ubuntu
            sudo apt-get update
            sudo apt-get install -y clamav clamav-daemon clamav-freshclam
        elif command_exists yum; then
            # CentOS/RHEL
            sudo yum install -y epel-release
            sudo yum install -y clamav clamav-devel clamav-update
        elif command_exists dnf; then
            # Fedora
            sudo dnf install -y clamav clamav-devel clamav-update
        else
            echo "❌ Package manager not found. Please install ClamAV manually."
            exit 1
        fi
    fi
}

# Configure ClamAV
configure_clamav() {
    echo "⚙️  Configuring ClamAV..."

    if [[ "$OS" == "macos" ]]; then
        # macOS configuration
        CLAMAV_CONFIG_DIR="/usr/local/etc/clamav"
        CLAMAV_LOG_DIR="/usr/local/var/log/clamav"
        CLAMAV_RUN_DIR="/usr/local/var/run/clamav"

        # Create directories
        sudo mkdir -p "$CLAMAV_LOG_DIR" "$CLAMAV_RUN_DIR"

        # Copy example configs if they don't exist
        if [[ ! -f "$CLAMAV_CONFIG_DIR/clamd.conf" ]]; then
            sudo cp "$CLAMAV_CONFIG_DIR/clamd.conf.sample" "$CLAMAV_CONFIG_DIR/clamd.conf"
            sudo sed -i '' 's/^Example/#Example/' "$CLAMAV_CONFIG_DIR/clamd.conf"
        fi

        if [[ ! -f "$CLAMAV_CONFIG_DIR/freshclam.conf" ]]; then
            sudo cp "$CLAMAV_CONFIG_DIR/freshclam.conf.sample" "$CLAMAV_CONFIG_DIR/freshclam.conf"
            sudo sed -i '' 's/^Example/#Example/' "$CLAMAV_CONFIG_DIR/freshclam.conf"
        fi

    elif [[ "$OS" == "linux" ]]; then
        # Linux configuration
        CLAMAV_CONFIG_DIR="/etc/clamav"
        CLAMAV_LOG_DIR="/var/log/clamav"
        CLAMAV_RUN_DIR="/var/run/clamav"

        # Most Linux distributions handle this automatically
        echo "✅ ClamAV configuration handled by package manager"
    fi
}

# Update virus definitions
update_definitions() {
    echo "🔄 Updating virus definitions..."

    if [[ "$OS" == "macos" ]]; then
        # Run freshclam to update definitions
        sudo freshclam
    elif [[ "$OS" == "linux" ]]; then
        sudo freshclam
    fi
}

# Start ClamAV service
start_service() {
    echo "🚀 Starting ClamAV service..."

    if [[ "$OS" == "macos" ]]; then
        # Use Homebrew services
        brew services start clamav

        # Also start freshclam for automatic updates
        brew services start clamav-freshclam 2>/dev/null || true

    elif [[ "$OS" == "linux" ]]; then
        # Use systemd
        sudo systemctl enable clamav-daemon
        sudo systemctl start clamav-daemon

        # Enable automatic updates
        sudo systemctl enable clamav-freshclam 2>/dev/null || true
        sudo systemctl start clamav-freshclam 2>/dev/null || true
    fi
}

# Test ClamAV installation
test_installation() {
    echo "🧪 Testing ClamAV installation..."

    # Wait a moment for service to start
    sleep 5

    # Test with clamdscan if available
    if command_exists clamdscan; then
        echo "Testing with clamdscan..."
        echo "Hello, World!" > /tmp/test_file.txt

        if clamdscan /tmp/test_file.txt; then
            echo "✅ ClamAV is working correctly!"
            rm -f /tmp/test_file.txt
        else
            echo "⚠️  ClamAV test failed, but this might be normal during initial setup"
        fi
    else
        echo "⚠️  clamdscan not available, testing with basic ping..."

        # Try to ping the daemon
        if command_exists clamd; then
            echo "✅ ClamAV daemon is installed"
        fi
    fi
}

# Show connection information
show_connection_info() {
    echo ""
    echo "📊 ClamAV Connection Information"
    echo "================================"

    if [[ "$OS" == "macos" ]]; then
        SOCKET_PATH="/usr/local/var/run/clamav/clamd.sock"
        echo "Socket Path: $SOCKET_PATH"
        echo "TCP: localhost:3310 (if socket unavailable)"

        if [[ -S "$SOCKET_PATH" ]]; then
            echo "✅ Socket file exists and is accessible"
        else
            echo "⚠️  Socket file not found - will use TCP connection"
        fi

    elif [[ "$OS" == "linux" ]]; then
        SOCKET_PATH="/var/run/clamav/clamd.ctl"
        echo "Socket Path: $SOCKET_PATH"
        echo "TCP: localhost:3310 (if socket unavailable)"

        if [[ -S "$SOCKET_PATH" ]]; then
            echo "✅ Socket file exists and is accessible"
        else
            echo "⚠️  Socket file not found - will use TCP connection"
        fi
    fi

    echo ""
    echo "🔧 Environment Variables (optional):"
    echo "export CLAMAV_SOCKET_PATH=$SOCKET_PATH"
    echo "export CLAMAV_HOST=localhost"
    echo "export CLAMAV_PORT=3310"
}

# Show Rails integration info
show_rails_info() {
    echo ""
    echo "🚀 Rails Integration"
    echo "===================="
    echo "Your SnapVault app will automatically detect and use ClamAV."
    echo ""
    echo "To test in Rails console:"
    echo "  bin/rails console"
    echo "  > FileProcessing::VirusScanner.instance.service_available?"
    echo "  > FileProcessing::VirusScanner.instance.version_info"
    echo ""
    echo "To start your Rails app:"
    echo "  bin/rails server"
    echo ""
    echo "Environment variables for development:"
    echo "  SKIP_VIRUS_SCAN=true          # Skip scanning in development"
    echo "  REQUIRE_VIRUS_SCAN=true       # Require scanning (production)"
    echo "  VIRUS_SCAN_FAIL_OPEN=true     # Allow files when scanner down"
}

# Main execution
main() {
    echo "Starting ClamAV setup for SnapVault..."
    echo ""

    # Check if ClamAV is already installed
    if command_exists clamd || command_exists clamdscan; then
        echo "✅ ClamAV appears to be already installed"
        read -p "Do you want to reconfigure it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping installation, showing connection info..."
            show_connection_info
            show_rails_info
            exit 0
        fi
    fi

    # Install and configure
    install_clamav
    configure_clamav
    update_definitions
    start_service
    test_installation
    show_connection_info
    show_rails_info

    echo ""
    echo "🎉 ClamAV setup complete!"
    echo "Your SnapVault application can now scan files for viruses locally."
    echo ""
    echo "Next steps:"
    echo "1. Start your Rails server: bin/rails server"
    echo "2. Upload a file to test virus scanning"
    echo "3. Check logs for scan results"
}

# Run main function
main "$@"
