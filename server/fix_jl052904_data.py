import sqlite3

# Connect to database
db_path = 'barangay.db'
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

print('🔧 Fixing jl052904@gmail.com data inconsistency...')

# Update jl052904@gmail.com to have correct verification_type
cursor.execute('''
    UPDATE users 
    SET verification_type = 'verified_non_resident' 
    WHERE email = 'jl052904@gmail.com'
''')

# Verify the fix
cursor.execute('SELECT verification_type, discount_rate, verified FROM users WHERE email = ?', ('jl052904@gmail.com',))
result = cursor.fetchone()

if result:
    verification_type, discount_rate, verified = result
    print(f'✅ Updated jl052904@gmail.com:')
    print(f'   verification_type: {verification_type}')
    print(f'   discount_rate: {discount_rate}')
    print(f'   verified: {verified}')
    
    if verification_type == 'verified_non_resident' and discount_rate == 0.05:
        print('✅ Data is now CONSISTENT!')
    else:
        print('❌ Data still inconsistent')
else:
    print('❌ User not found')

conn.commit()
conn.close()
