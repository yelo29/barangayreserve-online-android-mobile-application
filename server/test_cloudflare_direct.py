#!/usr/bin/env python3
"""
Direct Cloudflare tunnel test
"""

import subprocess
import time
import os

def test_cloudflare_direct():
    print("🌐 TESTING CLOUDFLARE TUNNEL DIRECTLY")
    print("=" * 50)
    
    # First, make sure Python server is running
    print("1. Checking if Python server is running...")
    try:
        import requests
        response = requests.get("http://localhost:8000/api/health", timeout=5)
        if response.status_code == 200:
            print("✅ Python server is running")
        else:
            print("❌ Python server not responding - start it first!")
            return
    except:
        print("❌ Python server not running - start with: python server.py")
        return
    
    # Start Cloudflare tunnel
    print("\n2. Starting Cloudflare tunnel...")
    cloudflare_path = r"C:\tools\cloudflare\cloudflared.exe"
    
    if os.path.exists(cloudflare_path):
        print(f"✅ Found cloudflared at: {cloudflare_path}")
        
        # Run cloudflared command
        try:
            print("🚀 Starting tunnel...")
            print("Command: .\\cloudflared.exe tunnel --url http://localhost:8000")
            print("\n🌐 Cloudflare will show a URL like:")
            print("   https://random-words.trycloudflare.com")
            print("\n📱 Use that URL in your Android app!")
            print("\nPress Ctrl+C to stop the tunnel")
            
            # This will run continuously
            subprocess.run([cloudflare_path, "tunnel", "--url", "http://localhost:8000"])
            
        except KeyboardInterrupt:
            print("\n🛑 Tunnel stopped by user")
        except Exception as e:
            print(f"❌ Error starting tunnel: {e}")
    else:
        print(f"❌ cloudflared not found at: {cloudflare_path}")

if __name__ == "__main__":
    test_cloudflare_direct()
