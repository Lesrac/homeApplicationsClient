import 'dart:convert';
import 'dart:io';

import '../models/credentials.dart';

class HeadersHelper {
  static Map<String, String> getHeaders(Credentials credentials) {
    return {
      HttpHeaders.authorizationHeader:
      'Basic ${base64Encode(utf8.encode('${credentials.username}:${credentials.password}'))}',
      'Content-Type': 'application/json',
    };
  }

  static Map<String, String> getAuthHeader(Credentials credentials) {
    return {
      HttpHeaders.authorizationHeader:
          'Basic ${base64Encode(utf8.encode('${credentials.username}:${credentials.password}'))}',
    };
  }
}