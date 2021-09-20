import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_demo/const.dart';
import 'package:flutter_chat_demo/home.dart';
import 'package:flutter_chat_demo/widget/loading.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({Key key, this.title}) : super(key: key);

  final String title;

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  SharedPreferences prefs;

  bool isLoading = false;
  bool isLoggedIn = false;
  User currentUser;

  @override
  void initState() {
    super.initState();
    isSignedIn(); //hàm kiểm tra xem có đăng nhập hay ko
  }
  void isSignedIn() async {//hàm kiểm tra xem có đăng nhập hay ko, đc gọi khi đăng xuất và khi mở lại ứng dụng
    this.setState(() {
      isLoading = true; //xoay vòng
    });

    prefs = await SharedPreferences.getInstance();  //moi các trường trong firebase
    print("prefs đăng xuất = " + prefs.toString());

    isLoggedIn = await googleSignIn.isSignedIn();
    print("isLoggedIn = " + isLoggedIn.toString());
    if (isLoggedIn) { //đảm bảo rằng 1 khi isLoggedIn = true thì luôn chuyển hướng sang màn hình đăng nhập
      print("prefs đăng nhập 1 = " + prefs.toString()); //khi mở lại ứng dụng trong trạng thái đã đăng nhập
      Navigator.push( //điều hướng sang màn hình mới (Màn hình HomeScreen)
        context,  //điều hướng từ
        MaterialPageRoute(  //điều hướng sang
            builder: (context) => //bên dưới cũng có hàm route sang HomeScreen, nhưng route ở đây là route khi kiểm tra ngay từ đầu, nếu đã đăng nhập lần trước rồi thì route ngay
                HomeScreen(currentUserId: prefs.getString('id'))),  //chuyển sang màn hình gồm các người đang online
      );
    }

    this.setState(() {
      isLoading = false;  //không xoay nữa
    });
  }




  Future<Null> handleSignIn() async {
    prefs = await SharedPreferences.getInstance();  //Instance of 'SharedPreferences', xuất hiện khi người dùng ấn nút đăng nhập

    this.setState(() {
      isLoading = true;
    });
    print("prefs đăng nhập 2 = " + prefs.toString());

    GoogleSignInAccount googleUser = await googleSignIn.signIn();
    GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    User firebaseUser = (await firebaseAuth.signInWithCredential(credential)).user; //lấy thông tin của người đăng nhập

    print("kiểm tra firebaseUser có null ko, firebaseUser = " + firebaseUser.toString());
    if (firebaseUser != null) { //nếu tìm thấy tài khoản google của người này trong firebase
      // Check is already sign up
      print("-------------------------------firebaseUser Khác null, = " + firebaseUser.toString());
      final QuerySnapshot result = await FirebaseFirestore.instance //QuerySnapshot dùng để chứa kết quả lấy được từ server
          .collection('users')
          .where('id', isEqualTo: firebaseUser.uid)
          .get(); //tìm kiếm id của người này dựa trên id trong tài khoản google đã đăng nhập

      print("Giá trị của QuerySnapshot result là " + result.toString());//[Instance of 'QueryDocumentSnapshot']

      final List<DocumentSnapshot> documents = result.docs; //mảng này chỉ chứa 0 hoặc 1 phần tử, tương ứng với người dùng chưa hoặc đã có trên firebase
      // print("-----------------------Giá trị của document = " + documents[0].toString());  //chứa duy nhất 1 phần tử, cho biết có query được hay ko
      if (documents.length == 0) {  //nếu người dùng đăng nhập lần đầu //document[0] = Instance of 'QueryDocumentSnapshot'
        // Update data to server if new user  //cập nhật dữ liệu lên server
        FirebaseFirestore.instance
            .collection('users')  //bảng user
            .doc(firebaseUser.uid)  //tại id mới
            .set({  //set các thuộc tính cho người dùng mới
          'nickname': firebaseUser.displayName,
          'photoUrl': firebaseUser.photoURL,
          'id': firebaseUser.uid,
          'createdAt': DateTime.now().millisecondsSinceEpoch.toString(),
          'chattingWith': null  ////người mà tôi đang chat ban đầu khi mới đăng nhập là null
        });

        // Write data to local
        currentUser = firebaseUser; //lấy dữ liệu trong firebase thì cũng cần phải cập nhật lại công cụ moi dữ liệu luôn
        await prefs.setString('id', currentUser.uid);
        await prefs.setString('nickname', currentUser.displayName);
        await prefs.setString('photoUrl', currentUser.photoURL);
      } else { //nếu người dùng đăng nhập lần hai trở đi, thì tức là đã có tên trong firestore rồi  //document[0] = Instance of 'QueryDocumentSnapshot'
        // Write data to local
        await prefs.setString('id', documents[0].data()['id']);
        await prefs.setString('nickname', documents[0].data()['nickname']);
        await prefs.setString('photoUrl', documents[0].data()['photoUrl']);
        await prefs.setString('aboutMe', documents[0].data()['aboutMe']);
      }
      Fluttertoast.showToast(msg: "Đăng nhập thành công");
      this.setState(() {
        isLoading = false;
      });

      Navigator.push( //điều hướng sang màn hình mới (Màn hình HomeScreen)
          context,
          MaterialPageRoute(//bên trên cũng có hàm route sang HomeScreen, nhưng route ở dưới đây là route khi ấn nút sign-in, chứ ko phải thực hiện ngay khi mở app lần đầu
              builder: (context) =>
                  HomeScreen(currentUserId: firebaseUser.uid)));
    } else {  //đăng nhập thất bại do không tìm thấy tên trên firestore
      print("firebaseUser bằng null null");
      Fluttertoast.showToast(msg: "Sign in fail");
      this.setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {  //chưa đăng nhập
    return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: <Widget>[
            Center(
              child: FlatButton(
                  onPressed: handleSignIn,
                  child: Text(
                    'SIGN IN WITH GOOGLE',
                    style: TextStyle(fontSize: 16.0),
                  ),
                  color: Color(0xffdd4b39),
                  highlightColor: Color(0xffff7f7f),
                  splashColor: Colors.transparent,
                  textColor: Colors.white,
                  padding: EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0)),
            ),

            // Loading
            Positioned(
              child: isLoading ? const Loading() : Container(), //có xoay vòng khi loading, còn nếu load xong rồi thì positioned là Container(), tức là rỗng
            ),
          ],
        ));
  }
}
