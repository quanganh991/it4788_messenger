import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'const.dart';
import 'login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Demo', //tên ứng dụng
      theme: ThemeData(
        primaryColor: themeColor,//màu thanh title của ứng dụng
      ),
      home: LoginScreen(title: 'CHAT DEMO'),  //chữ trên thanh title màu cam của ứng dụng //gọi file login.dart
      debugShowCheckedModeBanner: false,  //xóa cái chữ debug góc trên bên phải đi
    );
  }
}
