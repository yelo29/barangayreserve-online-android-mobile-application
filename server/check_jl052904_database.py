import sqlite3
import json

# Connect to database
db_path = 'barangay.db'
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Query jl052904@gmail.com user data
cursor.execute('SELECT * FROM users WHERE email = ?', ('jl052904@gmail.com',))
user = cursor.fetchone()

if user:
    # Get column names
    cursor.execute('PRAGMA table_info(users)')
    columns = [column[1] for column in cursor.fetchall()]
    
    print('🔍 Database Data for jl052904@gmail.com:')
    print('Columns:', columns)
    print('Values:', user)
    print()
    
    # Create dict for easier reading
    user_dict = dict(zip(columns, user))
    print('User Data:')
    for key, value in user_dict.items():
        if key in ['id', 'email', 'full_name', 'verified', 'verification_type', 'discount_rate']:
            print(f'  {key}: {value}')
    
    print()
    print('🚨 ISSUE ANALYSIS:')
    print(f'  verification_type: {user_dict.get("verification_type")}')
    print(f'  discount_rate: {user_dict.get("discount_rate")}')
    print(f'  Expected: verification_type = "verified_non_resident", discount_rate = 0.05')
    
    if user_dict.get('verification_type') == 'resident' and user_dict.get('discount_rate') == 0.05:
        print('  ❌ PROBLEM: User has "resident" type but 5% discount (should be verified_non_resident)')
    elif user_dict.get('verification_type') == 'verified_non_resident' and user_dict.get('discount_rate') == 0.05:
        print('  ✅ CORRECT: User has verified_non_resident type with 5% discount')
    else:
        print('  ❌ UNKNOWN STATE: Check database values')
else:
    print('❌ User jl052904@gmail.com not found in database')

conn.close()
