# Dynamic Server Configuration for DuckDNS
import os

# Load environment variables from .env file
def _load_env():
    try:
        env_file = os.path.join(os.path.dirname(__file__), '.env')
        if os.path.exists(env_file):
            with open(env_file, 'r') as f:
                for line in f:
                    if line.strip() and '=' in line:
                        key, value = line.strip().split('=', 1)
                        os.environ[key] = value
                        print(f"✅ Loaded: {key}={value[:20]}...")
    except Exception as e:
        print(f"⚠️  Could not load .env file: {e}")

# Load environment variables at import
_load_env()

class Config:
    """Server configuration that works with any IP/DuckDNS setup"""
    
    # Server settings
    HOST = os.getenv('SERVER_HOST', '0.0.0.0')  # Accept all connections
    PORT = int(os.getenv('SERVER_PORT', 8000))
    DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'
    
    # CORS settings - Allow all origins for DuckDNS flexibility
    CORS_ORIGINS = os.getenv('CORS_ORIGINS', '*')
    
    # Database settings - Always use server folder
    DATABASE_PATH = os.getenv('DB_PATH', os.path.join(os.path.dirname(__file__), 'barangay.db'))
    
    # DuckDNS settings (from environment)
    DUCKDNS_DOMAIN = os.getenv('DUCKDNS_DOMAIN', '')
    DUCKDNS_TOKEN = os.getenv('DUCKDNS_TOKEN', '')
    
    # Ngrok settings (from environment)
    NGROK_DOMAIN = os.getenv('NGROK_DOMAIN', '')
    
    @classmethod
    def get_server_url(cls):
        """Get the server URL based on environment or default"""
        # Priority: Ngrok > DuckDNS > Local
        if cls.NGROK_DOMAIN:
            return f"https://{cls.NGROK_DOMAIN}"
        elif cls.DUCKDNS_DOMAIN:
            return f"https://{cls.DUCKDNS_DOMAIN}"
        else:
            # Fallback to local detection
            return f"http://localhost:{cls.PORT}"
    
    @classmethod
    def get_cors_origins(cls):
        """Get CORS origins for Flutter app"""
        if cls.CORS_ORIGINS == '*':
            return ['*']  # Allow all origins
        else:
            return [origin.strip() for origin in cls.CORS_ORIGINS.split(',')]

# Environment variables for easy configuration
ENV_VARS = {
    # Ngrok Configuration (Leo's Account)
    'NGROK_DOMAIN': 'unstanding-unmenaced-pete.ngrok-free.dev',
    
    # Server Configuration
    'SERVER_HOST': '0.0.0.0',
    'SERVER_PORT': '8000', 
    'DEBUG': 'False',
    'CORS_ORIGINS': '*',
    'DB_PATH': 'server/barangay.db',
    
    # DuckDNS Configuration (backup)
    'DUCKDNS_DOMAIN': 'barangay-reserve.duckdns.org',
    'DUCKDNS_TOKEN': 'your-duckdns-token'
}
