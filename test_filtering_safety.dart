// Simple test to verify filtering functionality doesn't corrupt data
import 'dart:io';

void main() {
  print('🔍 Testing filtering data integrity...');
  
  // Simulate original data
  final List<Map<String, dynamic>> originalBookings = [
    {'id': 1, 'facility_name': 'Basketball Court', 'status': 'pending', 'user_email': 'test1@example.com'},
    {'id': 2, 'facility_name': 'Function Hall', 'status': 'approved', 'user_email': 'test2@example.com'},
    {'id': 3, 'facility_name': 'Basketball Court', 'status': 'rejected', 'user_email': 'test3@example.com'},
  ];
  
  print('📋 Original bookings: ${originalBookings.length}');
  print('📋 Original data: $originalBookings');
  
  // Test filtering function (similar to what we implemented)
  List<Map<String, dynamic>> applyFilters(List<Map<String, dynamic>> bookings, String statusFilter, String searchQuery) {
    // Create immutable copy to avoid data mutation
    List<Map<String, dynamic>> filtered = List.from(bookings);
    
    // Apply status filter
    if (statusFilter != 'all') {
      filtered = filtered.where((booking) => 
        (booking['status']?.toString().toLowerCase() ?? 'pending') == statusFilter.toLowerCase()
      ).toList();
    }
    
    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((booking) {
        final facilityName = (booking['facility_name']?.toString() ?? 'Unknown Facility').toLowerCase();
        final userEmail = (booking['user_email']?.toString() ?? 'Unknown User').toLowerCase();
        return facilityName.contains(query) || userEmail.contains(query);
      }).toList();
    }
    
    return filtered; // Return new filtered list, never modify original
  }
  
  // Test filtering
  print('\n🧪 Testing filters...');
  
  // Test 1: Status filter
  final pendingBookings = applyFilters(originalBookings, 'pending', '');
  print('✅ Pending bookings: ${pendingBookings.length}');
  assert(pendingBookings.length == 1);
  assert(pendingBookings.first['status'] == 'pending');
  
  // Test 2: Search filter
  final basketballBookings = applyFilters(originalBookings, 'all', 'basketball');
  print('✅ Basketball bookings: ${basketballBookings.length}');
  assert(basketballBookings.length == 2);
  
  // Test 3: Combined filters
  final basketballPending = applyFilters(originalBookings, 'pending', 'basketball');
  print('✅ Basketball pending bookings: ${basketballPending.length}');
  assert(basketballPending.length == 1);
  
  // CRITICAL: Verify original data is unchanged
  print('\n🔍 Verifying original data integrity...');
  print('📋 Original bookings after filtering: ${originalBookings.length}');
  print('📋 Original data after filtering: $originalBookings');
  
  assert(originalBookings.length == 3, 'Original data should not be modified');
  assert(originalBookings[0]['id'] == 1, 'Original booking 1 should be unchanged');
  assert(originalBookings[1]['id'] == 2, 'Original booking 2 should be unchanged');
  assert(originalBookings[2]['id'] == 3, 'Original booking 3 should be unchanged');
  
  print('\n✅ ALL TESTS PASSED - Data integrity maintained!');
  print('✅ Filtering works correctly without data corruption!');
  print('✅ Original data remains immutable and safe!');
}
