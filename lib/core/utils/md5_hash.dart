/// MD5 hashing matching the dashboard's js-md5 client-side hash.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

String md5Hash(String input) {
  return md5.convert(utf8.encode(input)).toString();
}
