#!/usr/bin/env python3
"""
Test and verify Cloudflare tunnel setup
"""

import os
import subprocess

def test_cloudflare_setup():
    print("🌐 TESTING CLOUDFLARE TUNNEL SETUP")
    print("=" * 50)
    
    # Check if cloudflared exists
    cloudflare_path = r"C:\tools\cloudflare\cloudflared.exe"
    if os.path.exists(cloudflare_path):
        print("✅ Cloudflare executable found")
    else:
        print("❌ Cloudflare executable not found at:", cloudflare_path)
        return
    
    # Check updated app config
    app_config_path = "../lib/config/app_config.dart"
    if os.path.exists(app_config_path):
        with open(app_config_path, 'r') as f:
            content = f.read()
            if 'trycloudflare.com' in content:
                print("✅ App config updated for Cloudflare")
            else:
                print("❌ App config not updated properly")
    else:
        print("❌ App config file not found")
    
    # Check updated .env
    if os.path.exists('.env'):
        with open('.env', 'r') as f:
            content = f.read()
            if 'CLOUDFLARE_TUNNEL=true' in content:
                print("✅ Server .env updated for Cloudflare")
            else:
                print("❌ Server .env not updated properly")
    else:
        print("❌ .env file not found")
    
    # Check startup script
    if os.path.exists('start_cloudflare_services.bat'):
        print("✅ Startup script created")
    else:
        print("❌ Startup script not found")
    
    print("\n🎯 SETUP VERIFICATION COMPLETE!")
    print("=" * 50)
    print("📋 TO START CLOUDFLARE TUNNEL:")
    print("1. Make sure Python server is running: python server.py")
    print("2. Start Cloudflare tunnel:")
    print("   cd C:\\tools\\cloudflare")
    print("   cloudflared tunnel --url http://localhost:8000")
    print("3. Or run: start_cloudflare_services.bat")
    print("\n🌐 Your app will be accessible at the URL shown by cloudflared")
    print("   (usually: https://random-words.trycloudflare.com)")
    print("\n✅ No bandwidth limits with Cloudflare!")

if __name__ == "__main__":
    test_cloudflare_setup()
