class ApiConstants {
  static String get baseUrl {
    final url = 'http://10.0.2.2:5000/api/';
    print('🌐 Usando API_URL: $url');
    return url;
  }

  static const Duration timeoutDuration =
      Duration(seconds: 8); // ⏱️ Ajusta según necesidad
}
