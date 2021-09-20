import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_demo/chat.dart';
import 'package:flutter_chat_demo/const.dart';
import 'package:flutter_chat_demo/settings.dart';
import 'package:flutter_chat_demo/widget/loading.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'main.dart';


class Choice {
  const Choice({this.title, this.icon});

  final String title;
  final IconData icon;
}


class HomeScreen extends StatefulWidget {
  final String currentUserId; //id của người dùng hiện tại đang đăng nhập

  HomeScreen({Key key, @required this.currentUserId}) : super(key: key);

  @override
  State createState() => HomeScreenState(currentUserId: currentUserId);
}

class HomeScreenState extends State<HomeScreen> {
  HomeScreenState({Key key, @required this.currentUserId});

  final String currentUserId;//id của người dùng hiện tại đang đăng nhập
  final GoogleSignIn googleSignIn = GoogleSignIn(); //kiểm tra đăng nhập
//  final FirebaseMessaging firebaseMessaging = FirebaseMessaging();  //đăng ký notification, lấy tin nhắn từ firebase, xem chi tiết ở dưới
//  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();  //Show notification, xem chi tiết ở dưới
  bool isLoading = false;
  List<Choice> choices = const <Choice>[  //các lựa chọn góc trên bên phải
    const Choice(title: 'Settings', icon: Icons.settings),
    const Choice(title: 'Log out', icon: Icons.exit_to_app),
  ];

  @override
  void initState() {
    super.initState();
    registerNotification();//  final FirebaseMessaging firebaseMessaging = FirebaseMessaging();  //đăng ký notification, lấy tin nhắn từ firebase
    configLocalNotification();//    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();  //Show notification
  }


  //nhóm chức năng notification
  final FirebaseMessaging firebaseMessaging = FirebaseMessaging();  //đăng ký notification, lấy tin nhắn từ firebase
  void registerNotification() { //được gọi khi đăng nhập
    firebaseMessaging.requestNotificationPermissions(); //yêu cầu cấp phép để đăng notification lên, hđh android sẽ luôn trả về null
    print("Đăng ký notification 1 = " + firebaseMessaging.requestNotificationPermissions().toString());

    firebaseMessaging.configure(onMessage: (Map<String, dynamic> message) {
      print('onMessage: $message'); //{notification: {title: You have a message from "Quang Anh Đinh", body: fhcdfh}, data: {}}
      print("Platform.isAndroid = " + Platform.isAndroid.toString());
      Platform.isAndroid
          ? showNotification(message['notification']) //điện thoại android, show phần title: You have a message from "Quang Anh Đinh", body: fhcdfh thôi
          : showNotification(message['aps']['alert']);  //điện thoại không phải android, là ios
      return;
    }, onResume: (Map<String, dynamic> message) {
      print('onResume: $message');
      return;
    }, onLaunch: (Map<String, dynamic> message) {
      print('onLaunch: $message');
      return;
    });

    print("Đăng ký notification 2");
    firebaseMessaging.getToken().then((token) { //thay đổi phiên đăng nhập
      print('token: $token');
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({'pushToken': token});
    }).catchError((err) {
      print("Lỗi firebase = " + err.toString());
      Fluttertoast.showToast(msg: err.message.toString());
    });
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();  //Show notification
  void showNotification(message) async {  //chức năng show notification, được gọi mỗi khi có noti đến
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails( //android
      Platform.isAndroid
          ? 'com.example.messengerfakebook' //android
          : 'com.example.messengerfakebook',  //ios
      'Flutter chat demo',
      'your channel description',
      playSound: true,  //âm thanh notification
      enableVibration: true,  //rung
      importance: Importance.Max,
      priority: Priority.High,
    );
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails(); //ios
    var platformChannelSpecifics = new NotificationDetails(androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);

    print("message = " + message);
//    print(message['body'].toString());  //nội dung tin nhắn từ người gửi đến
//    print(json.encode(message));

    await flutterLocalNotificationsPlugin.show(0, message['title'].toString(),
        message['body'].toString(), platformChannelSpecifics,
        payload: json.encode(message));
    //Future<void> show(int id, String title, String body,
    //       NotificationDetails notificationDetails,
    //       {String payload})

   await flutterLocalNotificationsPlugin.show(
       0, 'plain title', 'plain body', platformChannelSpecifics,
       payload: 'item x');
  }

  void configLocalNotification() {
    var initializationSettingsAndroid = new AndroidInitializationSettings('app_icon');
    var initializationSettingsIOS = new IOSInitializationSettings();
    var initializationSettings = new InitializationSettings(initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  //hết nhóm chức năng notification














  Future<Null> handleSignOut() async {  //xử lý sự kiện người dùng ấn vào nút đăng xuất
    this.setState(() {
      isLoading = true;
    });

    await FirebaseAuth.instance.signOut();
    await googleSignIn.disconnect();
    await googleSignIn.signOut();

    this.setState(() {
      isLoading = false;
    });

    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => MyApp()), //gọi lại MyApp, trong myapp lại gọi login, vì đã đăng xuất rồi nên sẽ là màn hình login
            (Route<dynamic> route) => false);
  }











  //xử lý sự kiện ấn nút back khi ở màn hình home
  Future<bool> onBackPress() {  //đang ở màn hình home mà ấn back thì mở hộp thoại "Exit app, Are you sure to exit app" lên
    openDialog();
    return Future.value(false);
  }
  //xử lý sự kiện ấn nút back khi ở màn hình home
  Future<Null> openDialog() async {//đang ở màn hình home mà ấn back thì mở hộp thoại "Exit app, Are you sure to exit app" lên
    switch (await showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            contentPadding:
                EdgeInsets.only(left: 0.0, right: 0.0, top: 0.0, bottom: 0.0),
            children: <Widget>[
              Container(
                color: themeColor,
                margin: EdgeInsets.all(0.0),
                padding: EdgeInsets.only(bottom: 10.0, top: 10.0),
                height: 100.0,
                child: Column(
                  children: <Widget>[
                    Container(
                      child: Icon(
                        Icons.exit_to_app,
                        size: 30.0,
                        color: Colors.white,
                      ),
                      margin: EdgeInsets.only(bottom: 10.0),
                    ),
                    Text(
                      'Exit app',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Are you sure to exit app?',
                      style: TextStyle(color: Colors.white70, fontSize: 14.0),
                    ),
                  ],
                ),
              ),
              SimpleDialogOption( //khi ấn nút cancel
                onPressed: () {
                  Navigator.pop(context, 0); //khi ấn nút back tại mà hình home, có 1 hộp thoại đè lên, ấn cancel để xóa hộp thoại này ra khỏi stack
                },
                child: Row(
                  children: <Widget>[
                    Container(
                      child: Icon(
                        Icons.cancel,
                        color: primaryColor,
                      ),
                      margin: EdgeInsets.only(right: 10.0),
                    ),
                    Text(
                      'CANCEL',
                      style: TextStyle(
                          color: primaryColor, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, 1);////khi ấn nút back tại mà hình home, có 1 hộp thoại đè lên, ấn cancel để xóa "Phần dưới hộp thoại == ứng dụng chính" ra khỏi stack
                },
                child: Row(
                  children: <Widget>[
                    Container(
                      child: Icon(
                        Icons.check_circle,
                        color: primaryColor,
                      ),
                      margin: EdgeInsets.only(right: 10.0),
                    ),
                    Text(
                      'YES',
                      style: TextStyle(
                          color: primaryColor, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
            ],
          );
        })) {
      case 0:
        break;
      case 1:
        exit(0);
        break;
    }
  }
  //kết thúc xử lý sự kiện ấn nút back khi ở màn hình home





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar( //thanh tiêu đề
        title: Text(
          'FAKEBOOK MESSENGER',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: <Widget>[
          PopupMenuButton<Choice>(
            onSelected: onItemMenuPress,
            itemBuilder: (BuildContext context) {
              return choices.map((Choice choice) {
                return PopupMenuItem<Choice>(
                    value: choice,
                    child: Row(
                      children: <Widget>[
                        Icon(
                          choice.icon,
                          color: primaryColor,
                        ),
                        Container(
                          width: 10.0,
                        ),
                        Text(
                          choice.title,
                          style: TextStyle(color: primaryColor),
                        ),
                      ],
                    ));
              }).toList();
            },
          ),
        ],
      ),



      body: WillPopScope( //nội dung
        child: Stack(
          children: <Widget>[
            // List
            Container(
              child: StreamBuilder(
                stream:
                    FirebaseFirestore.instance.collection('users').snapshots(), //query bảng users trong database
                builder: (context, snapshot1) {
                  if (!snapshot1.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                      ),
                    );
                  } else {
                    return ListView.builder(
                      padding: EdgeInsets.all(10.0),
                      itemBuilder: (context, index) =>  //từng người 1 sẽ được hiển thị
                      buildItem(context, snapshot1.data.documents[index]), //hiển thị listview
                      itemCount: snapshot1.data.documents.length,
                    );
                  }
                },
              ),
            ),

            // Loading
            Positioned(
              child: isLoading ? const Loading() : Container(),
            )
          ],
        ),
        onWillPop: onBackPress,
      ),
    );
  }






  //mỗi người trong màn hình home mà mình muốn chat với
  Widget buildItem(BuildContext context, DocumentSnapshot document) {
    print("-----------------giá trị của document là = " + document.data().toString());
    if (document.data()['id'] == currentUserId) { //không hiển thị người dùng hiện tại (tôi) lên màn hình danh sách người muốn chat
      return Container();
    // } else if(!(document.data()['nickname'].toString().contains('Quang') || document.data()['nickname'].toString().contains('Vat'))){
    //   return Container();
    } else {
      return Container( //3 thành phần gồm: avatar, nickname, aboutme
        child: FlatButton(
          child: Row( //2 thành phần gầm avatar, (nickname, aboutme)
            children: <Widget>[
              Material( //avatar
                child: document.data()['photoUrl'] != null
                    ? CachedNetworkImage(
                        placeholder: (context, url) => Container(
                          child: CircularProgressIndicator(
                            strokeWidth: 1.0,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(themeColor),
                          ),
                          width: 50.0,
                          height: 50.0,
                          padding: EdgeInsets.all(15.0),
                        ),
                        imageUrl: document.data()['photoUrl'],
                        width: 50.0,
                        height: 50.0,
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        Icons.account_circle, //avatar mặc định
                        size: 50.0,
                        color: greyColor,
                      ),
                borderRadius: BorderRadius.all(Radius.circular(25.0)),
                clipBehavior: Clip.hardEdge,
              ),
              Flexible( //(nickname, aboutme)
                child: Container(
                  child: Column(  //(nickname, aboutme) là 1 cột gồm 2 thành phần: nickname, aboutme
                    children: <Widget>[
                      Container(  //nickname
                        child: Text(
                          'Nickname: ${document.data()['nickname']}',
                          style: TextStyle(color: primaryColor),
                        ),
                        alignment: Alignment.centerLeft,
                        margin: EdgeInsets.fromLTRB(10.0, 0.0, 0.0, 5.0),
                      ),
                      Container(  //aboutme
                        child: Text(
                          'About me: ${document.data()['aboutMe'] ?? 'Not available'}',
                          style: TextStyle(color: primaryColor),
                        ),
                        alignment: Alignment.centerLeft,
                        margin: EdgeInsets.fromLTRB(10.0, 0.0, 0.0, 0.0),
                      )
                    ],
                  ),
                  margin: EdgeInsets.only(left: 20.0),
                ),
              ),
            ],
          ),
          onPressed: () { ////ấn vào 1 trong 3 thành phần avatar, nickname, aboutme thì chuyển sang màn hình chat, truyền vào id người chat và avatar của người chat
            Navigator.push(
                context,
                MaterialPageRoute(  //chuyển sang màn hình chat, truyền vào id người chat và avatar của người chat
                    builder: (context) => Chat(
                          peerNickname: document.data()['nickname'],
                          peerId: document.id,
                          peerAvatar: document.data()['photoUrl'],
                        )));
          },
          color: greyColor2,
          padding: EdgeInsets.fromLTRB(25.0, 10.0, 25.0, 10.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        ),
        margin: EdgeInsets.only(bottom: 10.0, left: 5.0, right: 5.0),
      );
    }
  }







//khi ấn vào nút góc trên bên phải
  void onItemMenuPress(Choice choice) { //khi ấn vào nút góc trên bên phải
    if (choice.title == 'Log out') {  //đăng xuất
      handleSignOut();
    } else {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => ChatSettings()));  //chuyển sang màn hình setting nếu ấn vào nút còn lại (setting)
    }
  }
}
