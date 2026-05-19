/// Dynamic App Configuration for Global Server Access
/// Cloudflare Tunnel for Global Access

class AppConfig {
  // Cloudflare tunnel URL (your permanent domain)
  static String _baseUrl = 'https://barangayreserve.dpdns.org';
  
  /// Get the current base URL
  static String get baseUrl => _baseUrl;
  
  /// Check if URL uses Cloudflare
  static bool isCloudflareUrl(String url) {
    return url.contains('trycloudflare.com') || url.contains('cloudflareaccess.com');
  }
  
  /// Extract domain from URL
  static String extractDomain(String url) {
    try {
      Uri uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return url;
    }
  }
  
  /// Check if URL is valid
  static bool isValidUrl(String url) {
    try {
      Uri uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
  
  /// Check if URL uses Ngrok
  static bool isNgrokUrl(String url) {
    final domain = extractDomain(url);
    return domain.contains('ngrok.io') ||
           domain.contains('ngrok.free.app') ||
           domain.contains('ngrok-free.dev');
  }
  
  /// Check if URL uses DuckDNS
  static bool isDuckDnsUrl(String url) {
    final domain = extractDomain(url);
    return domain.contains('duckdns.org');
  }
  
  /// Get configuration info
  static Map<String, dynamic> getConfigInfo() {
    return {
      'baseUrl': _baseUrl,
      'isCloudflare': isCloudflareUrl(_baseUrl),
      'isNgrok': isNgrokUrl(_baseUrl),
      'isDuckDns': isDuckDnsUrl(_baseUrl),
      'domain': extractDomain(_baseUrl),
      'isValid': isValidUrl(_baseUrl),
    };
  }
}