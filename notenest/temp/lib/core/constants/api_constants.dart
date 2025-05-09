class ApiConstants {
  static String get baseUrl {
    final url = 'http://192.168.1.13:5000/api/';
    print('🌐 Usando API_URL: $url');
    return url;
  }

  static const Duration timeoutDuration =
      Duration(seconds: 8); // ⏱️ Ajusta según necesidad
}
