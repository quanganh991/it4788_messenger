import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_demo/const.dart';

import 'package:flutter_chat_demo/widget/full_photo.dart';
import 'package:flutter_chat_demo/widget/loading.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';



class Chat extends StatelessWidget {
  final String peerNickname;
  final String peerId;
  final String peerAvatar;

  Chat({Key key, @required this.peerId, @required this.peerAvatar, this.peerNickname})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    //lấy thông tin người mà tôi đang chat với


    return Scaffold(
      appBar: AppBar( //thanh dài màu cam trên đầu chứa chữ 'CHAT'
        title: Text(
          peerNickname,
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),//primaryColor = 0xff203152
        ),
        centerTitle: true,
      ),
      body: ChatScreen( //màn hình ChatScreen
        peerId: peerId,
        peerAvatar: peerAvatar,
      ),
    );
  }


}

class ChatScreen extends StatefulWidget { //màn hình ChatScreen
  final String peerId;
  final String peerAvatar;

  ChatScreen({Key key, @required this.peerId, @required this.peerAvatar})
      : super(key: key);

  @override
  State createState() =>
      ChatScreenState(peerId: peerId, peerAvatar: peerAvatar);   //màn hình ChatScreen
}

class ChatScreenState extends State<ChatScreen> {//màn hình ChatScreen
  ChatScreenState({Key key, @required this.peerId, @required this.peerAvatar});

  String peerId;  //id của người mà mình đang chat với
  String peerAvatar;
  String id;  //id của tôi

  List<QueryDocumentSnapshot> listMessage = new List.from([]);  //lưu các tin nhắn query được
  int _limit = 20;  //số tin nhắn đang xuất hiện trên màn hình ban đầu lấy 20 tin nhắn, sau đó + thêm 20 lần lượt khi reach the top
  final int _limitIncrement = 20;//20 tin nhắn thì load 1 lần
  String groupChatId; //id cho mỗi cặp chat với nhau, có n người dùng thì có nC2 cái groupChatId khác nhau
  SharedPreferences prefs;  //lấy dữ liệu từ firebase

  File imageFile; //chứa ảnh
  bool isLoading;
  bool isShowSticker; //sticker
  String imageUrl;  //chứa đường dẫn ảnh

  final TextEditingController textEditingController = TextEditingController();  //chứa tin nhắn đang soạn
  final ScrollController listScrollController = ScrollController();
  final FocusNode focusNode = FocusNode();

  _scrollListener() { //offset là khoảng cách từ tin nhắn hiện tại nhất đến tin nhắn mới nhất, maxScrollExtent là kc từ tin nhắn cũ nhất đến tin nhắn mới nhất
    if (listScrollController.offset >= listScrollController.position.maxScrollExtent && !listScrollController.position.outOfRange) {
      print("chạm đến những tin nhắn cũ nhất, listScrollController = " + listScrollController.toString());
      print("listScrollController.position.maxScrollExtent = " + listScrollController.position.maxScrollExtent.toString());  //chạm đến những tin nhắn cũ nhất
      setState(() {
        print("reach the bottom");
        _limit += _limitIncrement;  //thì sẽ load thêm 20 tin nữa
      });
    }
    if (listScrollController.offset <= listScrollController.position.minScrollExtent && !listScrollController.position.outOfRange) {
      print("chạm đến những tin nhắn mới nhất, listScrollController = " + listScrollController.toString()); //chạm đến những tin nhắn mới nhất
      setState(() {
        print("reach the top");
      });
    }
  }

  @override
  void initState() {
    super.initState();
    focusNode.addListener(onFocusChange);
    listScrollController.addListener(_scrollListener);

    groupChatId = '';

    isLoading = false;
    isShowSticker = false;
    imageUrl = '';






    //Xuất ra file JSON
    getApplicationDocumentsDirectory().then((Directory directory) {
      dir = directory;
      jsonFile = new File(dir.path + "/" + fileName);
      print("--------------Khởi tạo file--------------" + dir.path + "/" + fileName);
      fileExists = jsonFile.existsSync();
      if (fileExists) {
        print("-------------File đã tồn tại---------------");
        this.setState(
                () => fileContent = json.decode(jsonFile.readAsStringSync())
        );
      }
    });
    //Xuất ra file JSON







    readLocal();//cập nhật người mà tôi đang chat
  }






  //xuất ra file JSON
  File jsonFile;
  Directory dir;
  String fileName = "NoiDungTinNhan.json";
  bool fileExists = false;
  Map<String, dynamic> fileContent;

  void createFile(
      Map<String, dynamic> content, Directory dir, String fileName) {
    print("--------------Đang tạo file------------");
    File file = new File(dir.path + "/" + fileName);
    file.createSync();
    fileExists = true;
    file.writeAsStringSync(json.encode(content));
  }

  void writeToFile(String key, dynamic value) {
    print("---------------Đang viết lên file-------------");
    Map<String, dynamic> content = {key: value};
    if (fileExists) {
      print("-------------File đã tồn tại---------------");
      Map<String, dynamic> jsonFileContent = json.decode(jsonFile.readAsStringSync());
      print("-----------------Nội dung trước khi thêm của JSON là = " + jsonFileContent.toString());
      jsonFileContent.addAll(content);
      print("-----------------Nội dung sau khi thêm của JSON là = " + jsonFileContent.toString());

      jsonFile.writeAsStringSync(json.encode(jsonFileContent));
    } else {
      print("---------------File không tồn tại---------------");
      createFile(content, dir, fileName);
    }
    this.setState(() => fileContent = json.decode(jsonFile.readAsStringSync()));
    print("Nội dung của JSON là: " + fileContent.toString());
  }
  //xuất ra file JSON






  void onFocusChange() {  //ẩn sticker khi bàn phím xuất hiện
    if (focusNode.hasFocus) {
      setState(() {
        isShowSticker = false;
      });
    }
  }

  readLocal() async { //cập nhật người mà tôi đang chat
    prefs = await SharedPreferences.getInstance();
    id = prefs.getString('id') ?? ''; //id của tôi
    if (id.hashCode <= peerId.hashCode) { //id của người mà mình đang chat với
      groupChatId = '$id-$peerId';  //trường hợp này thường xảy ra hơn
    } else {
      groupChatId = '$peerId-$id';  //hiếm khi xảy ra
    }
    print("tôi id = " + id);
    print("người đang chat với tôi peerId = " + peerId);
    print("cuộc trò chuyện groupChatId = " + groupChatId);

    FirebaseFirestore.instance
        .collection('users')
        .doc(id)  //tôi
        .update({'chattingWith': peerId});  //cập nhật người mà tôi đang chat

    setState(
            () {}
            );
  }////cập nhật người mà tôi đang chat


  void getSticker() { //ấn nút chọn sticker để gửi sticker đi
    // Hide keyboard when sticker appear
    focusNode.unfocus();
    setState(() {
      isShowSticker = !isShowSticker;
    });
  }

  void onSendMessage(String content, int type) {  //khi ấn nút gửi tin nhắn đi, gửi kiểu tin nhắn và nội dung tin nhắn đi
    // type: 0 = text, 1 = image, 2 = sticker
    if (content.trim() != '') { //xử lý khoảng trắng
      textEditingController.clear();  //gửi 1 phát là khung nhập tin nhắn ko còn gì nữa

      var documentReference = FirebaseFirestore.instance  //truy vấn 'messages' theo id
          .collection('messages') //from messages
          .doc(groupChatId)
          .collection(groupChatId)
          .doc(DateTime.now().millisecondsSinceEpoch.toString()); //do các tin nhắn được lưu trong firestore có id = timestamp

      print("Vừa gửi tin nhắn đi documentReference = " + documentReference.toString());

      FirebaseFirestore.instance.runTransaction((transaction) async { //lưu vào database
        transaction.set(
          documentReference,
          {
            'idFrom': id,
            'idTo': peerId,
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
            'content': content,
            'type': type
          },
        );
      });//lưu vào database



      //gọi hàm xuất ra JSON
      writeToFile(id, content);
      //gọi hàm xuất ra JSON









      listScrollController.animateTo(700.0, duration: Duration(milliseconds: 1000), curve: Curves.easeInCubic);  // hoạt ảnh static const Cubic easeOut = Cubic(0.0, 0.0, 0.58, 1.0);
      //milliseconds thể hiện tốc độ trượt ban đầu khi có tin nhắn mới
      //nếu ko có animateTo thì sẽ không thể trượt xuống khi có tin nhắn mới
    } else {  //nếu người dùng gửi khoảng trắng đi
      Fluttertoast.showToast(
          msg: 'Bạn chưa nhập nội dung',
          backgroundColor: Colors.black,
          textColor: Colors.red);
    }
  }
  Widget buildItem(int index, DocumentSnapshot document) {
    if (document.data()['idFrom'] == id) {  //tin nhắn tôi gửi đi sẽ được xếp ở bên phải
      // Right (my message)
      return Row(
        children: <Widget>[
          document.data()['type'] == 0  //text
              // Text
              ? Container(
                  child: Text(
                    document.data()['content'], //nội dung của tin nhắn tôi gửi đi
                    style: TextStyle(color: primaryColor),
                  ),
                  padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0),
                  width: 200.0,
                  decoration: BoxDecoration(
                      color: greyColor2,
                      borderRadius: BorderRadius.circular(8.0)),
                  margin: EdgeInsets.only(
                      bottom: isLastMessageRight(index) ? 20.0 : 10.0,
                      right: 10.0),
                )



              : document.data()['type'] == 1  //tôi gửi ảnh đi
                  // Image
                  ? Container(
                      child: FlatButton(
                        child: Material(
                          child: CachedNetworkImage(
                            placeholder: (context, url) => Container(
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(themeColor),
                              ),
                              width: 200.0,
                              height: 200.0,
                              padding: EdgeInsets.all(70.0),
                              decoration: BoxDecoration(
                                color: greyColor2,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8.0),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Material(
                              child: Image.asset(
                                'images/img_not_available.jpeg',
                                width: 200.0,
                                height: 200.0,
                                fit: BoxFit.cover,
                              ),
                              borderRadius: BorderRadius.all(
                                Radius.circular(8.0),
                              ),
                              clipBehavior: Clip.hardEdge,
                            ),
                            imageUrl: document.data()['content'],
                            width: 200.0,
                            height: 200.0,
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                          clipBehavior: Clip.hardEdge,
                        ),
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => FullPhoto(  //ẩn vào ảnh thì mở ảnh dưới dạng FULLPHOTO
                                      url: document.data()['content'])));
                        },
                        padding: EdgeInsets.all(0),
                      ),
                      margin: EdgeInsets.only(
                          bottom: isLastMessageRight(index) ? 20.0 : 10.0,
                          right: 10.0),
                    )



                  // Sticker
                  : Container(  //tôi gửi sticker đi
                      child: Image.asset(
                        'images/${document.data()['content']}.gif', //nội dung ảnh sticker
                        width: 100.0,
                        height: 100.0,
                        fit: BoxFit.cover,
                      ),
                      margin: EdgeInsets.only(
                          bottom: isLastMessageRight(index) ? 20.0 : 10.0,
                          right: 10.0),
                    ),
        ],
        mainAxisAlignment: MainAxisAlignment.end, //tôi gửi đi thì chữ ở bên phải
      );
    } else {  //tin nhắn tôi nhận từ bên kia sẽ được xếp ở bên trái
      // Left (peer message)
      return Container(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                isLastMessageLeft(index)
                    ? Material(
                        child: CachedNetworkImage(
                          placeholder: (context, url) => Container(
                            child: CircularProgressIndicator(
                              strokeWidth: 1.0,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(themeColor),
                            ),
                            width: 35.0,
                            height: 35.0,
                            padding: EdgeInsets.all(10.0),
                          ),
                          imageUrl: peerAvatar,
                          width: 35.0,
                          height: 35.0,
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.circular(18.0),
                        ),
                        clipBehavior: Clip.hardEdge,
                      )
                    : Container(width: 35.0),
                document.data()['type'] == 0
                    ? Container(
                        child: Text(
                          document.data()['content'],
                          style: TextStyle(color: Colors.white),
                        ),
                        padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0),
                        width: 200.0,
                        decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(8.0)),
                        margin: EdgeInsets.only(left: 10.0),
                      )
                    : document.data()['type'] == 1
                        ? Container(
                            child: FlatButton(
                              child: Material(
                                child: CachedNetworkImage(
                                  placeholder: (context, url) => Container(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          themeColor),
                                    ),
                                    width: 200.0,
                                    height: 200.0,
                                    padding: EdgeInsets.all(70.0),
                                    decoration: BoxDecoration(
                                      color: greyColor2,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8.0),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Material(
                                    child: Image.asset(
                                      'images/img_not_available.jpeg',
                                      width: 200.0,
                                      height: 200.0,
                                      fit: BoxFit.cover,
                                    ),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(8.0),
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                  ),
                                  imageUrl: document.data()['content'],
                                  width: 200.0,
                                  height: 200.0,
                                  fit: BoxFit.cover,
                                ),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8.0)),
                                clipBehavior: Clip.hardEdge,
                              ),
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => FullPhoto(//ẩn vào ảnh thì mở ảnh dưới dạng FULLPHOTO
                                            url: document.data()['content'])));
                              },
                              padding: EdgeInsets.all(0),
                            ),
                            margin: EdgeInsets.only(left: 10.0),
                          )
                        : Container(
                            child: Image.asset(
                              'images/${document.data()['content']}.gif',
                              width: 100.0,
                              height: 100.0,
                              fit: BoxFit.cover,
                            ),
                            margin: EdgeInsets.only(
                                bottom: isLastMessageRight(index) ? 20.0 : 10.0,
                                right: 10.0),
                          ),
              ],
            ),

            // Time
            isLastMessageLeft(index)
                ? Container(
                    child: Text(
                      DateFormat('dd MMM kk:mm').format(
                          DateTime.fromMillisecondsSinceEpoch(
                              int.parse(document.data()['timestamp']))),
                      style: TextStyle(
                          color: greyColor,
                          fontSize: 12.0,
                          fontStyle: FontStyle.italic),
                    ),
                    margin: EdgeInsets.only(left: 50.0, top: 5.0, bottom: 5.0),
                  )
                : Container()
          ],
          crossAxisAlignment: CrossAxisAlignment.start, //tin nhắn của người gửi cho tôi, tôi nhận thì ở bên trái
        ),
        margin: EdgeInsets.only(bottom: 10.0),
      );
    }
  }






  bool isLastMessageLeft(int index) { //kiểm tra có phải tin nhắn cuối cùng hay ko, cuối cùng thì cách widget phía dưới nó 20, ko thì 10 thôi
    if ((index > 0 && //2 tin nhắn không phải cuối cùng nhưng gửi cách nhau lâu về thời gian -> thêm nhãn thời gian vào mỗi tin nhắn
            listMessage != null &&
            listMessage[index - 1].data()['idFrom'] == id) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  bool isLastMessageRight(int index) { //kiểm tra có phải tin nhắn cuối cùng hay ko, cuối cùng thì cách widget phía dưới nó 20, ko thì 10 thôi
    if ((index > 0 &&//2 tin nhắn không phải cuối cùng nhưng gửi cách nhau lâu về thời gian -> thêm nhãn thời gian vào mỗi tin nhắn
            listMessage != null &&
            listMessage[index - 1].data()['idFrom'] != id) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> onBackPress() {  //ấn nút back thì quây về màn hình home
    if (isShowSticker) {
      setState(() {
        isShowSticker = false;
      });
    } else {
      FirebaseFirestore.instance
          .collection('users')
          .doc(id)  //vẫn là người dùng hiện tại
          .update({'chattingWith': null});  //nhưng ko chat với ai nữa
      Navigator.pop(context);
    }

    return Future.value(false);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              // List of messages
              buildListMessage(),

              // Sticker
              (isShowSticker ? buildSticker() : Container()),

              // Input content
              buildInput(),
            ],
          ),

          // Loading
          buildLoading()
        ],
      ),
      onWillPop: onBackPress,
    );
  }






  Widget buildSticker() { //các sticker
    return Container(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              FlatButton(
                onPressed: () => onSendMessage('mimi1', 2),
                child: Image.asset(
                  'images/mimi1.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              ),
              FlatButton(
                onPressed: () => onSendMessage('mimi2', 2),
                child: Image.asset(
                  'images/mimi2.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              ),
              FlatButton(
                onPressed: () => onSendMessage('mimi3', 2),
                child: Image.asset(
                  'images/mimi3.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              )
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          ),
          Row(
            children: <Widget>[
              FlatButton(
                onPressed: () => onSendMessage('mimi4', 2),
                child: Image.asset(
                  'images/mimi4.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              ),
              FlatButton(
                onPressed: () => onSendMessage('mimi5', 2),
                child: Image.asset(
                  'images/mimi5.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              ),
              FlatButton(
                onPressed: () => onSendMessage('mimi6', 2),
                child: Image.asset(
                  'images/mimi6.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              )
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          ),
          Row(
            children: <Widget>[
              FlatButton(
                onPressed: () => onSendMessage('mimi7', 2),
                child: Image.asset(
                  'images/mimi7.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              ),
              FlatButton(
                onPressed: () => onSendMessage('mimi8', 2),
                child: Image.asset(
                  'images/mimi8.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              ),
              FlatButton(
                onPressed: () => onSendMessage('mimi9', 2),
                child: Image.asset(
                  'images/mimi9.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              )
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          )
        ],
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      ),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: greyColor2, width: 0.5)),
          color: Colors.white),
      padding: EdgeInsets.all(5.0),
      height: 180.0,
    );
  }//các sticker







  Widget buildLoading() {
    return Positioned(
      child: isLoading ? const Loading() : Container(),
    );
  }

  Widget buildInput() { //thanh ngang dưới cùng chứa 4 item
    return Container(
      child: Row(
        children: <Widget>[
          // Button send image
          Material(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 1.0),
              child: IconButton(
                icon: Icon(Icons.image),
                onPressed: getImage,
                color: primaryColor,
              ),
            ),
            color: Colors.white,
          ),
          Material(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 1.0),
              child: IconButton(
                icon: Icon(Icons.face),
                onPressed: getSticker,
                color: primaryColor,
              ),
            ),
            color: Colors.white,
          ),

          // Edit text
          Flexible(
            child: Container(
              child: TextField(
                onSubmitted: (value) {
                  onSendMessage(textEditingController.text, 0);
                },
                style: TextStyle(color: primaryColor, fontSize: 15.0),
                controller: textEditingController,
                decoration: InputDecoration.collapsed(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(color: greyColor),
                ),
                focusNode: focusNode,
              ),
            ),
          ),

          // Button send message
          Material(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8.0),
              child: IconButton(
                icon: Icon(Icons.send),
                onPressed: () => onSendMessage(textEditingController.text, 0),
                color: primaryColor,
              ),
            ),
            color: Colors.white,
          ),
        ],
      ),
      width: double.infinity,
      height: 50.0,
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: greyColor2, width: 0.5)),
          color: Colors.white),
    );
  }

  Widget buildListMessage() { //màn hình hiển thị các tin nhắn của 2 người
    return Flexible(
      child: groupChatId == ''  //người tôi muốn chat không tồn tại
          ? Center(//người tôi muốn chat không tồn tại thì trả về 1 màn hình rỗng
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(themeColor)))
          : StreamBuilder(  //realtime
              stream: FirebaseFirestore.instance
                  .collection('messages') //truy vấn bảng messages
                  .doc(groupChatId) //where
                  .collection(groupChatId)  //trong bảng messages lưu nC2 cuộc trò chuyện khác nhau
                  .orderBy('timestamp', descending: true)
                  .limit(_limit + 6)  //mỗi lần lấy 20 đoạn chat trò chuyện thôi
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {//người tôi chưa từng chat với người này bào giờ
                  print("Bắt đầu chat với snapshot = " + snapshot.toString());
                  return Center(
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(themeColor)));
                } else {
                  print("Có thêm 1 tin nhắn snapshot = " + snapshot.toString());
                  listMessage.addAll(snapshot.data.documents);  //thêm tin nhắn query được vào listMessage  //biến listMessage này ko có cũng đc
                  print("Số tin nhắn hiện tại = " + snapshot.data.documents.length.toString());
                  print("---------------listMessage = " + listMessage.toString());
                  // print("khoảng cách từ tin nhắn hiện tại đến tin nhắn mới nhất = " + listScrollController.position.maxScrollExtent.toString());
                  return ListView.builder(
                    padding: EdgeInsets.all(10.0),
                    itemBuilder: (context, index) => buildItem(index, snapshot.data.documents[index]),
                    itemCount: snapshot.data.documents.length,  //ko có thì listview sẽ dài vô hạn
                    reverse: true,  //tin nhắn phía dưới là mới nhất, càng lên trên càng cũ
                    controller: listScrollController, //hiệu ứng chuyển động khi có tin nhắn mới
                  );
                }
              },
            ),
    );
  }






  Future getImage() async { //ấn nút chọn ảnh để gửi ảnh đi
    ImagePicker imagePicker = ImagePicker();
    PickedFile pickedFile;

    pickedFile = await imagePicker.getImage(source: ImageSource.gallery);
    imageFile = File(pickedFile.path);
    print("----------------------đường dẫn ảnh = " + imageFile.toString());

    if (imageFile != null) {
      setState(() {
        isLoading = true;
      });
      uploadFile();
    }
  }

  Future uploadFile() async { ////ấn nút chọn ảnh để gửi ảnh đi
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    StorageReference reference = FirebaseStorage.instance.ref().child(fileName);
    StorageUploadTask uploadTask = reference.putFile(imageFile);
    StorageTaskSnapshot storageTaskSnapshot = await uploadTask.onComplete;
    storageTaskSnapshot.ref.getDownloadURL().then((downloadUrl) {
      imageUrl = downloadUrl;
      setState(() {
        isLoading = false;
        onSendMessage(imageUrl, 1);
      });
    }, onError: (err) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: 'This file is not an image' + err.toString());
    });
  }
}
