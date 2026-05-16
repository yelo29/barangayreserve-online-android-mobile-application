import 'package:flutter/material.dart';

class OfficialBookingsPage extends StatelessWidget {
  final List<Map<String, dynamic>> allBookings;

  const OfficialBookingsPage({super.key, required this.allBookings});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    
    if (allBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 60, color: isDarkMode ? Colors.grey.shade600 : Colors.grey),
            const SizedBox(height: 16),
            Text(
              "No bookings yet.",
              style: TextStyle(fontSize: 18, color: isDarkMode ? Colors.grey.shade600 : Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: allBookings.length,
      itemBuilder: (context, index) {
        final booking = allBookings[index];
        final facilityName = booking['facilityName'] as String? ?? 'N/A';

        // Determine status color
        Color statusColor;
        String statusText = (booking['status'] as String? ?? 'pending').toUpperCase();
        switch (statusText) {
          case 'APPROVED':
            statusColor = Colors.green.shade400;
            break;
          case 'COMPLETED':
            statusColor = Colors.grey.shade600;
            break;
          default: // PENDING
            statusColor = Colors.orange.shade400;
            break;
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16.0),
          color: isDarkMode ? Colors.grey.shade800 : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            leading: CircleAvatar(
              backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.blue.shade100,
              child: Icon(Icons.event_available, color: isDarkMode ? Colors.blue.shade300 : Colors.blue),
            ),
            title: Text(
              facilityName,
              style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87),
            ),
            subtitle: Text(
              "${booking['date'] as String? ?? ''} at ${booking['time'] as String? ?? ''}\nBooked by: ${booking['name'] as String? ?? ''}",
              style: TextStyle(color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600, height: 1.4),
            ),
            trailing: Chip(
              label: Text(
                statusText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
              ),
              backgroundColor: statusColor,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        );
      },
    );
  }
}
