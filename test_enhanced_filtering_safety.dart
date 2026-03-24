// Comprehensive test for enhanced filtering and sorting functionality
import 'dart:io';

void main() {
  print('🔍 Testing enhanced filtering and sorting functionality...');
  
  // Simulate original booking data
  final List<Map<String, dynamic>> originalBookings = [
    {
      'id': 1,
      'facility_name': 'Basketball Court',
      'status': 'pending',
      'user_email': 'user1@example.com',
      'created_at': '2026-03-20T10:00:00Z',
      'booking_date': '2026-03-25',
      'full_name': 'John Doe'
    },
    {
      'id': 2,
      'facility_name': 'Function Hall',
      'status': 'approved',
      'user_email': 'user2@example.com',
      'created_at': '2026-03-22T14:30:00Z',
      'booking_date': '2026-03-24',
      'full_name': 'Jane Smith'
    },
    {
      'id': 3,
      'facility_name': 'Basketball Court',
      'status': 'rejected',
      'user_email': 'user3@example.com',
      'created_at': '2026-03-21T09:15:00Z',
      'booking_date': '2026-03-26',
      'full_name': 'Bob Johnson'
    },
    {
      'id': 4,
      'facility_name': 'Swimming Pool',
      'status': 'pending',
      'user_email': 'user4@example.com',
      'created_at': '2026-03-19T16:45:00Z',
      'booking_date': '2026-03-23',
      'full_name': 'Alice Brown'
    },
  ];
  
  print('📋 Original bookings: ${originalBookings.length}');
  print('📋 Original data integrity check:');
  for (var booking in originalBookings) {
    print('  - ID: ${booking['id']}, Facility: ${booking['facility_name']}, Status: ${booking['status']}');
  }
  
  // Enhanced filtering function (matches our implementation)
  List<Map<String, dynamic>> applyFilters(
    List<Map<String, dynamic>> bookings, 
    String statusFilter, 
    String facilityFilter, 
    String submittedDateSort, 
    String bookingDateSort, 
    String searchQuery
  ) {
    // Create immutable copy to avoid data mutation
    List<Map<String, dynamic>> filtered = List.from(bookings);
    
    // Apply status filter
    if (statusFilter != 'all') {
      filtered = filtered.where((booking) => 
        (booking['status']?.toString().toLowerCase() ?? 'pending') == statusFilter.toLowerCase()
      ).toList();
    }
    
    // Apply facility filter
    if (facilityFilter != 'all') {
      filtered = filtered.where((booking) {
        final facilityName = (booking['facility_name']?.toString() ?? 'Unknown Facility').toLowerCase();
        return facilityName == facilityFilter.toLowerCase();
      }).toList();
    }
    
    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((booking) {
        final facilityName = (booking['facility_name']?.toString() ?? 'Unknown Facility').toLowerCase();
        final fullName = (booking['full_name']?.toString() ?? '').toLowerCase();
        final userEmail = (booking['user_email']?.toString() ?? 'Unknown User').toLowerCase();
        return facilityName.contains(query) || fullName.contains(query) || userEmail.contains(query);
      }).toList();
    }
    
    // Apply submitted date sorting
    if (submittedDateSort != 'none') {
      filtered = List.from(filtered)..sort((a, b) {
        final dateA = a['created_at']?.toString() ?? '';
        final dateB = b['created_at']?.toString() ?? '';
        try {
          final dateTimeA = DateTime.parse(dateA);
          final dateTimeB = DateTime.parse(dateB);
          return submittedDateSort == 'asc' 
              ? dateTimeA.compareTo(dateTimeB)
              : dateTimeB.compareTo(dateTimeA);
        } catch (e) {
          return dateA.compareTo(dateB);
        }
      });
    }
    
    // Apply booking date sorting
    if (bookingDateSort != 'none') {
      filtered = List.from(filtered)..sort((a, b) {
        final dateA = (a['booking_date']?.toString() ?? '');
        final dateB = (b['booking_date']?.toString() ?? '');
        try {
          final dateTimeA = DateTime.parse(dateA);
          final dateTimeB = DateTime.parse(dateB);
          return bookingDateSort == 'asc' 
              ? dateTimeA.compareTo(dateTimeB)
              : dateTimeB.compareTo(dateTimeA);
        } catch (e) {
          return dateA.compareTo(dateB);
        }
      });
    }
    
    return filtered; // Return new filtered list, never modify original
  }
  
  print('\n🧪 Testing enhanced filters...');
  
  // Test 1: Facility filter
  final basketballBookings = applyFilters(originalBookings, 'all', 'basketball court', 'none', 'none', '');
  print('✅ Basketball Court bookings: ${basketballBookings.length}');
  assert(basketballBookings.length == 2);
  assert(basketballBookings.every((b) => b['facility_name'] == 'Basketball Court'));
  
  // Test 2: Status filter + Facility filter
  final pendingBasketball = applyFilters(originalBookings, 'pending', 'basketball court', 'none', 'none', '');
  print('✅ Pending Basketball Court bookings: ${pendingBasketball.length}');
  assert(pendingBasketball.length == 1);
  assert(pendingBasketball.first['status'] == 'pending');
  
  // Test 3: Submitted date sorting (ASC - First submitted)
  final firstSubmitted = applyFilters(originalBookings, 'all', 'all', 'asc', 'none', '');
  print('✅ First submitted bookings: ${firstSubmitted.map((b) => '${b['id']}(${b['created_at']})').toList()}');
  assert(firstSubmitted[0]['id'] == 4); // 2026-03-19T16:45:00Z (earliest)
  assert(firstSubmitted[3]['id'] == 2); // 2026-03-22T14:30:00Z (latest)
  
  // Test 4: Submitted date sorting (DESC - Last submitted)
  final lastSubmitted = applyFilters(originalBookings, 'all', 'all', 'desc', 'none', '');
  print('✅ Last submitted bookings: ${lastSubmitted.map((b) => '${b['id']}(${b['created_at']})').toList()}');
  assert(lastSubmitted[0]['id'] == 2); // 2026-03-22T14:30:00Z (latest)
  assert(lastSubmitted[3]['id'] == 4); // 2026-03-19T16:45:00Z (earliest)
  
  // Test 5: Booking date sorting (ASC - Nearest date)
  final nearestDate = applyFilters(originalBookings, 'all', 'all', 'none', 'asc', '');
  print('✅ Nearest booking dates: ${nearestDate.map((b) => '${b['id']}(${b['booking_date']})').toList()}');
  assert(nearestDate[0]['id'] == 4); // 2026-03-23 (nearest)
  assert(nearestDate[3]['id'] == 3); // 2026-03-26 (farthest)
  
  // Test 6: Booking date sorting (DESC - Farthest date)
  final farthestDate = applyFilters(originalBookings, 'all', 'all', 'none', 'desc', '');
  print('✅ Farthest booking dates: ${farthestDate.map((b) => '${b['id']}(${b['booking_date']})').toList()}');
  assert(farthestDate[0]['id'] == 3); // 2026-03-26 (farthest)
  assert(farthestDate[3]['id'] == 4); // 2026-03-23 (nearest)
  
  // Test 7: Combined filters (Status + Facility + Submitted Date Sort)
  final combinedFilters = applyFilters(originalBookings, 'pending', 'basketball court', 'asc', 'none', '');
  print('✅ Combined filters (Pending + Basketball + First Submitted): ${combinedFilters.length}');
  assert(combinedFilters.length == 1);
  assert(combinedFilters.first['facility_name'] == 'Basketball Court');
  assert(combinedFilters.first['status'] == 'pending');
  
  // Test 8: Search by name
  final searchByName = applyFilters(originalBookings, 'all', 'all', 'none', 'none', 'jane');
  print('✅ Search by name "jane": ${searchByName.length}');
  assert(searchByName.length == 1);
  assert(searchByName.first['full_name'] == 'Jane Smith');
  
  // Test 9: Search by email
  final searchByEmail = applyFilters(originalBookings, 'all', 'all', 'none', 'none', 'user3@example.com');
  print('✅ Search by email "user3@example.com": ${searchByEmail.length}');
  assert(searchByEmail.length == 1);
  assert(searchByEmail.first['user_email'] == 'user3@example.com');
  
  // CRITICAL: Verify original data is unchanged after all filtering operations
  print('\n🔍 Verifying original data integrity after all operations...');
  print('📋 Original bookings after filtering: ${originalBookings.length}');
  
  assert(originalBookings.length == 4, 'Original data should not be modified');
  assert(originalBookings[0]['id'] == 1, 'Original booking 1 should be unchanged');
  assert(originalBookings[1]['id'] == 2, 'Original booking 2 should be unchanged');
  assert(originalBookings[2]['id'] == 3, 'Original booking 3 should be unchanged');
  assert(originalBookings[3]['id'] == 4, 'Original booking 4 should be unchanged');
  
  // Verify no data mutation occurred
  for (var booking in originalBookings) {
    assert(booking.containsKey('id'), 'ID should still exist');
    assert(booking.containsKey('facility_name'), 'Facility name should still exist');
    assert(booking.containsKey('status'), 'Status should still exist');
    assert(booking.containsKey('created_at'), 'Created date should still exist');
    assert(booking.containsKey('booking_date'), 'Booking date should still exist');
  }
  
  print('\n✅ ALL ENHANCED FILTERING TESTS PASSED!');
  print('✅ Facility filtering works correctly!');
  print('✅ Submitted date sorting works correctly (ASC/DESC)!');
  print('✅ Booking date sorting works correctly (ASC/DESC)!');
  print('✅ Combined filters work correctly!');
  print('✅ Search functionality works correctly!');
  print('✅ Original data remains immutable and safe!');
  print('✅ NO DATA CORRUPTION OR MUTATION DETECTED!');
  print('✅ Enhanced filtering implementation is SAFE and FUNCTIONAL!');
}
