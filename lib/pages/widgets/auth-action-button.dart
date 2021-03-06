import 'package:face_net_authentication/locator.dart';
import 'package:face_net_authentication/pages/db/databse_helper.dart';
import 'package:face_net_authentication/pages/models/user.model.dart';
import 'package:face_net_authentication/pages/sign-up.dart' as signup;
import 'package:face_net_authentication/pages/thank_you.dart';
import 'package:face_net_authentication/pages/widgets/app_button.dart';
import 'package:face_net_authentication/pages/widgets/home.dart';
import 'package:face_net_authentication/services/camera.service.dart';
import 'package:face_net_authentication/services/ml_service.dart';
import 'package:face_net_authentication/styles/colors.dart';
import 'package:face_net_authentication/tabs/home_page.dart';
import 'package:flutter/material.dart';
// import 'package:image/image.dart';
import 'dart:convert';
import '../landing.dart';
import 'app_text_field.dart';
import 'package:http/http.dart' as http;
import 'package:face_net_authentication/main.dart';
import 'package:face_net_authentication/main.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

int? status;
bool check_face = false;
// final storageRef = FirebaseStorage.instance.ref();
// final newImage = storageRef.child("images/test/");

class AuthActionButton extends StatefulWidget {
  AuthActionButton(
      {Key? key,
      // required this.img,
      required this.onPressed,
      required this.isLogin,
      required this.reload});
  final Function onPressed;
  final bool isLogin;
  final Function reload;
  // final File? img;

  @override
  _AuthActionButtonState createState() => _AuthActionButtonState();
}

class _AuthActionButtonState extends State<AuthActionButton> {
  final MLService _mlService = locator<MLService>();
  final CameraService _cameraService = locator<CameraService>();

  final TextEditingController _matricTextEditingController =
      TextEditingController(text: '');
  final TextEditingController _fnameTextEditingController =
      TextEditingController(text: '');
  final TextEditingController _lnameTextEditingController =
      TextEditingController(text: '');
  final TextEditingController _passwordTextEditingController =
      TextEditingController(text: '');
  File? img;

  User? predictedUser;

  Future _signUp(context, File imgFile) async {
    // print(widget.img);
    print('inside signup');
    DatabaseHelper _databaseHelper = DatabaseHelper.instance;
    List predictedData = _mlService.predictedData;
    String matric = _matricTextEditingController.text;
    String fname = _fnameTextEditingController.text;
    String lname = _lnameTextEditingController.text;
    String password = _passwordTextEditingController.text;
    // File? imgFile = widget.img;
    // print('IMAGE string INSIDE SIGNUP ${widget.img}');
    User userToSave = User(
      // imgFile: widget.img.toString(),
      matric: matric,
      fname: fname,
      lname: lname,
      password: password,
      modelData: predictedData,
    );
    // await _databaseHelper.insert(userToSave);
    await attemptSignUp(
        _matricTextEditingController.text,
        _fnameTextEditingController.text,
        _lnameTextEditingController.text,
        _passwordTextEditingController.text);

    status == 1
        ? {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  content: Text(
                      'This matric number is already registered in the system!'),
                );
              },
            ),
          }
        : status == 2
            ? {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      content: Text(
                          'This matric number was not found in the system'),
                    );
                  },
                ),
              }
            : status == 0
                ? {
                    await FirebaseStorage.instance
                        .ref('images/${_matricTextEditingController.text}')
                        .putFile(imgFile),
                    userToSave.imgLink = await FirebaseStorage.instance
                        .ref('images/${_matricTextEditingController.text}')
                        .getDownloadURL(),
                    print('USER TO SAVE ${userToSave.imgLink}'),
                    await _databaseHelper.insertUser(userToSave),
                    this._mlService.setPredictedData([]),
                    print('imgfile in _signup ${imgFile.toString()}'),
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (BuildContext context) => ThankYouPage(
                                  title: 'Thank you for your registration! ',
                                )))
                  }
                : () {};
  }

  Future<Object> attemptSignUp(
      String matric, String fname, String lname, String password) async {
    print(fname);
    var res = await http.post(Uri.parse('$SERVER_IP/signup'), body: {
      "user_id": matric,
      "fname": fname,
      "lname": lname,
      "pw": password,
    });
    print("RES BODY${res.body}");
    if (res.body
        .contains('A user with that matric/staff number already exists')) {
      return 409;
    }
    if (res.body.contains('Student has been registered to the system')) {
      status = 0;
    } else if (res.body.contains('This user is already registered')) {
      status = 1;
    } else if (res.body.contains('Student not found in the system')) {
      status = 2;
    }
    print('DESTATUS ${status}');

    print('res body: ${res.body}');
    return res.statusCode;
  }

  Future<String> attemptLogIn(String matric, String password) async {
    print('in ATTEMPT LOGIN');
    var res = await http.post(Uri.parse("$SERVER_IP/login"),
        body: {"user_id": matric, "pw": password});
    print('response in attempt login: ${res.body}');
    if (res.statusCode == 200) return res.body;
    return res.statusCode.toString();
  }

  Future _signIn(context) async {
    String matric = _matricTextEditingController.text;
    String password = _passwordTextEditingController.text;

    String jwt = await attemptLogIn(matric, password);
    print('JWT ${jwt}');

    if (jwt == null) {
      print('JWT IS null');
    }
    if (jwt != null) {
      check_face = true;
      storage.write(key: "jwt", value: jwt);
      // Navigator.push(context,
      //     MaterialPageRoute(builder: (context) => Home.fromBase64(jwt)));
    } else {
      check_face = false;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text('No user was found with these credentials!'),
          );
        },
      );
    }
    if (check_face) {
      if (this.predictedUser!.password == password) {
        // Navigator.push(
        //     context,
        //     MaterialPageRoute(
        //         builder: (BuildContext context) => Homepage(
        //               this.predictedUser!.matric,
        //               imagePath: _cameraService.imagePath!,
        //             )));
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => Home.fromBase64(jwt)));
      } else {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text('Wrong password!'),
            );
          },
        );
      }
    }
  }

  Future<User?> _predictUser() async {
    User? userAndPass = await _mlService.predict();
    return userAndPass;
  }

  Future onTap() async {
    try {
      Map<String, Object?> onPressedData = await widget.onPressed();
      dynamic faceDetected = onPressedData['isDetected'];
      dynamic imgFile = onPressedData['imgFile'];
      // File newImgFile = igFile;

      // bool faceDetected = onPressedData{['1']};
      print('detected?  ${faceDetected}');
      print('image file:  ${imgFile.toString()}');
      // print('ON TAP PARAMETER ZERO ${faceDetected}');
      if (faceDetected) {
        if (widget.isLogin) {
          var user = await _predictUser();
          if (user != null) {
            this.predictedUser = user;
          }
        }

        PersistentBottomSheetController bottomSheetController =
            Scaffold.of(context)
                .showBottomSheet((context) => signSheet(context, imgFile));
        bottomSheetController.closed.whenComplete(() => widget.reload());
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // final File imgBuild = widget.img!;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: clrbrown,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: clrbrown.withOpacity(0.1),
              blurRadius: 1,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        width: MediaQuery.of(context).size.width * 0.8,
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CAPTURE',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(
              width: 10,
            ),
            Icon(Icons.camera_alt, color: Colors.white)
          ],
        ),
      ),
    );
  }

  signSheet(BuildContext context, File imgFile) {
    print('img string  inside sign sheet ${imgFile.toString()}');
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          widget.isLogin && predictedUser != null
              ? Container(
                  child: Text(
                    'Welcome back, ' + predictedUser!.fname + '!',
                    style: TextStyle(fontSize: 20),
                  ),
                )
              : widget.isLogin
                  ? Container(
                      child: Text(
                      'Student not found',
                      style: TextStyle(fontSize: 20),
                    ))
                  : Container(),
          Container(
            child: Column(
              children: [
                !widget.isLogin
                    ? AppTextField(
                        controller: _matricTextEditingController,
                        labelText: "Matric number",
                      )
                    : Container(),
                SizedBox(height: 10),
                !widget.isLogin
                    ? AppTextField(
                        controller: _fnameTextEditingController,
                        labelText: "First Name",
                      )
                    : Container(),
                SizedBox(height: 10),
                !widget.isLogin
                    ? AppTextField(
                        controller: _lnameTextEditingController,
                        labelText: "Last Name",
                      )
                    : Container(),
                SizedBox(height: 10),
                widget.isLogin && predictedUser == null
                    ? Container()
                    : AppTextField(
                        controller: _passwordTextEditingController,
                        labelText: "Password",
                        isPassword: true,
                      ),
                SizedBox(height: 10),
                Divider(),
                SizedBox(height: 10),
                widget.isLogin && predictedUser != null
                    ? AppButton(
                        text: 'LOGIN',
                        onPressed: () async {
                          _signIn(context);
                        },
                        icon: Icon(
                          Icons.login,
                          color: Colors.white,
                        ),
                      )
                    : !widget.isLogin
                        ? AppButton(
                            text: 'Register',
                            onPressed: () async {
                              await _signUp(context, imgFile);
                            },
                            icon: Icon(
                              Icons.person_add,
                              color: Colors.white,
                            ),
                          )
                        : Container(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
