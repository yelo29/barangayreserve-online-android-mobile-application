#!/usr/bin/env python3
"""
Setup Cloudflare Tunnel for Barangay Reserve Application
"""

import os
import subprocess
import json
from config import Config

def setup_cloudflare_tunnel():
    print("🌐 SETTING UP CLOUDFLARE TUNNEL")
    print("=" * 50)
    
    # Cloudflare tunnel configuration
    tunnel_config = {
        "ingress": [
            {
                "hostname": "barangay-reserve.trycloudflare.com",
                "service": "http://localhost:8000"
            },
            {
                "service": "http_status:404"
            }
        ]
    }
    
    # Create tunnel config file
    config_file = "cloudflare-tunnel.json"
    with open(config_file, 'w') as f:
        json.dump(tunnel_config, f, indent=2)
    
    print(f"✅ Created tunnel config: {config_file}")
    
    # Update app config for Cloudflare
    print("\n🔧 UPDATING APP CONFIGURATION...")
    
    app_config_content = '''/// Dynamic App Configuration for Global Server Access
/// Cloudflare Tunnel for Global Access

class AppConfig {
  // Cloudflare tunnel URL
  static String _baseUrl = 'https://barangay-reserve.trycloudflare.com';
  
  /// Get the current base URL
  static String get baseUrl => _baseUrl;
  
  /// Check if URL uses Cloudflare
  static bool isCloudflareUrl(String url) {
    return url.contains('trycloudflare.com') || url.contains('cloudflareaccess.com');
  }
  
  /// Extract domain from URL
  static String extractDomain(String url) {
    try {
      Uri uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return url;
    }
  }
  
  /// Check if URL is valid
  static bool isValidUrl(String url) {
    try {
      Uri uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
  
  /// Check if URL uses Ngrok
  static bool isNgrokUrl(String url) {
    final domain = extractDomain(url);
    return domain.contains('ngrok.io') ||
           domain.contains('ngrok.free.app') ||
           domain.contains('ngrok-free.dev');
  }
  
  /// Check if URL uses DuckDNS
  static bool isDuckDnsUrl(String url) {
    final domain = extractDomain(url);
    return domain.contains('duckdns.org');
  }
  
  /// Get configuration info
  static Map<String, dynamic> getConfigInfo() {
    return {
      'baseUrl': _baseUrl,
      'isCloudflare': isCloudflareUrl(_baseUrl),
      'isNgrok': isNgrokUrl(_baseUrl),
      'isDuckDns': isDuckDnsUrl(_baseUrl),
      'domain': extractDomain(_baseUrl),
      'isValid': isValidUrl(_baseUrl),
    };
  }
}'''
    
    with open('../lib/config/app_config.dart', 'w') as f:
        f.write(app_config_content)
    
    print("✅ Updated app_config.dart for Cloudflare")
    
    # Update server config
    print("\n🔧 UPDATING SERVER CONFIGURATION...")
    
    server_env_content = '''# Cloudflare Tunnel Configuration
CLOUDFLARE_TUNNEL=true
TUNNEL_HOSTNAME=barangay-reserve.trycloudflare.com

# Ngrok Configuration (backup)
NGROK_DOMAIN=unstanding-unmenaced-pete.ngrok-free.dev

# DuckDNS Configuration (backup)
DUCKDNS_DOMAIN=barangay-reserve.duckdns.org
DUCKDNS_TOKEN=17e7be97-c49c-4e8b-8a8a-be09070d6354

# Server Settings
SERVER_HOST=0.0.0.0
SERVER_PORT=8000
DEBUG=False

# CORS Settings (allow all origins)
CORS_ORIGINS=*

# Database
DB_PATH=barangay.db'''
    
    with open('.env', 'w') as f:
        f.write(server_env_content)
    
    print("✅ Updated .env for Cloudflare")
    
    # Create startup script
    startup_script = '''@echo off
echo ========================================
echo   BARANGAY RESERVE - CLOUDFLARE TUNNEL
echo ========================================
echo.

echo ✅ Configuration Status:
echo    Android App: https://barangay-reserve.trycloudflare.com
echo    Server: Python on port 8000
echo    Tunnel: Cloudflare (free, no limits)
echo.

echo 🚀 Starting Services...
echo.

REM Start Python Server
echo Starting Python server on port 8000...
cd /d "%~dp0"
start "Python Server" cmd /k python server.py

REM Wait a moment for server to start
timeout /t 3 /nobreak >nul

REM Start Cloudflare Tunnel
echo Starting Cloudflare tunnel...
cd /d "C:\\tools\\cloudflare"
start "Cloudflare Tunnel" cmd /k cloudflared tunnel --url http://localhost:8000

echo.
echo ✅ Both services started!
echo 📱 Android app ready: https://barangay-reserve.trycloudflare.com
echo 🌐 Tunnel URL will be shown in Cloudflare window
echo.
pause'''
    
    with open('start_cloudflare_services.bat', 'w') as f:
        f.write(startup_script)
    
    print("✅ Created startup script: start_cloudflare_services.bat")
    
    print("\n🎯 CLOUDFLARE SETUP COMPLETE!")
    print("=" * 50)
    print("📋 NEXT STEPS:")
    print("1. Start Python server: python server.py")
    print("2. Start Cloudflare tunnel: cloudflared tunnel --url http://localhost:8000")
    print("3. Or run: start_cloudflare_services.bat")
    print("4. Update Android app with new tunnel URL")
    print("\n🌐 Your app will be accessible at:")
    print("   https://barangay-reserve.trycloudflare.com")
    print("\n✅ No bandwidth limits with Cloudflare!")

if __name__ == "__main__":
    setup_cloudflare_tunnel()
