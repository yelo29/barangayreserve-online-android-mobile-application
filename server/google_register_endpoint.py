@app.route('/api/auth/google-register', methods=['POST'])
def google_register():
    try:
        data = request.get_json()
        id_token = data.get('idToken')
        email = data.get('email')
        
        if not id_token or not email:
            return jsonify({
                'success': False,
                'message': 'Missing idToken or email'
            }), 400
        
        # Verify Google ID token
        google_response = requests.get(
            f'https://oauth2.googleapis.com/tokeninfo?id_token={id_token}'
        )
        
        if google_response.status_code != 200:
            return jsonify({
                'success': False,
                'message': 'Invalid Google token or email may not be correctly spelled'
            }), 401
        
        token_data = google_response.json()
        
        # Verify the email matches
        if token_data.get('email') != email:
            return jsonify({
                'success': False,
                'message': 'Email mismatch'
            }), 401
        
        # Check if user already exists in database
        conn = sqlite3.connect(Config.DATABASE_PATH)
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM users WHERE email = ?', (email,))
        user = cursor.fetchone()
        
        if user:
            # User already exists - cannot register
            conn.close()
            return jsonify({
                'success': False,
                'message': 'Account already exists. Please login instead.',
                'is_existing_user': True
            }), 409  # Conflict status
        
        # New user - create account as UNVERIFIED resident
        cursor.execute('''
            INSERT INTO users (email, password, full_name, role, verified, verification_type, discount_rate, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            email,
            'gmail-auth-no-password',  # placeholder password
            token_data.get('name', ''),
            'resident',
            False,  # Gmail auth = NOT automatically verified - must go through verification process
            'unverified',  # New Gmail users start as unverified
            0.0,  # No discount until verified
            datetime.utcnow()
        ))
        
        user_id = cursor.lastrowid
        
        # Get the created user
        cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
        new_user = cursor.fetchone()
        
        user_data = {
            'id': new_user[0],
            'email': new_user[1],
            'full_name': new_user[3],  # full_name is at index 3
            'role': new_user[4],        # role is at index 4
            'verified': bool(new_user[5]),  # verified is at index 5
            'verification_type': new_user[6],  # verification_type is at index 6
            'discount_rate': new_user[7],    # discount_rate is at index 7
            'contact_number': new_user[8],    # contact_number is at index 8
            'address': new_user[9],          # address is at index 9
            'created_at': new_user[15]       # created_at is at index 15
        }
        
        # Generate JWT token for session
        token_payload = {
            'user_id': user_id,
            'email': email,
            'exp': datetime.now(timezone.utc) + timedelta(days=7)
        }
        
        jwt_token = jwt.encode(token_payload, 'barangay-reserve-secret-key-32-chars-long', algorithm='HS256')
        
        conn.commit()
        conn.close()
        
        return jsonify({
            'success': True,
            'user': user_data,
            'token': jwt_token,
            'message': 'Registration successful',
            'is_existing_user': False
        })
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500
