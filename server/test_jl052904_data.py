import requests
import json

# Test backend API for jl052904@gmail.com
url = 'https://barangayreserve.dpdns.org/api/auth/google-login'
data = {
    'email': 'jl052904@gmail.com',
    'id_token': 'test_token',
    'full_name': 'Test User'
}

try:
    response = requests.post(url, json=data, timeout=10)
    print('🔍 Backend API Response for jl052904@gmail.com:')
    print(f'Status: {response.status_code}')
    if response.status_code == 200:
        result = response.json()
        user = result.get('user', {})
        print(f'Verification Type: {user.get("verification_type", "NOT_FOUND")}')
        print(f'Discount Rate: {user.get("discount_rate", "NOT_FOUND")}')
        print(f'Verified: {user.get("verified", "NOT_FOUND")}')
        print(f'Full Response: {json.dumps(result, indent=2)}')
    else:
        print(f'Error: {response.text}')
except Exception as e:
    print(f'❌ Error: {e}')
