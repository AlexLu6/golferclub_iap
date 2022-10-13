import 'package:flutter/cupertino.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:emojis/emoji.dart';
import 'package:badges/badges.dart';
import 'dataModel.dart';
import 'createPage.dart';
import 'firebase_options.dart';
import 'locale/language.dart';
import 'locale/app_localizations_delegate.dart';
import 'activity.dart';
import 'course_order.dart';
import 'purchase.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  prefs = await SharedPreferences.getInstance();
  await locationGranted();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: [
        const AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: [
        const Locale('en'),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ],
      onGenerateTitle: (context) => Language.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      title: 'Golfer Groups',
      theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: Colors.blue,
//        accentColor: Colors.white,
          visualDensity: VisualDensity.adaptivePlatformDensity),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentPageIndex = 0;
  int _gID = 1;
  bool isRegistered = false, isUpdate = false;
  
  @override
  void initState() {
    initPlatformState();
    golferID = prefs!.getInt('golferID') ?? 0;
    userHandicap = prefs!.getDouble('handicap') ?? initHandicap;
    expiredDate = prefs!.getString('expired')?? '';
    loadMyGroup();
    loadMyActivities();
    loadMyScores();
    FirebaseFirestore.instance.collection('Golfers').where('uid', isEqualTo: golferID).get().then((value) {
      value.docs.forEach((result) {
        golferDoc = result.id;
        var items = result.data();
        userName = items['name'];
        userPhone = items['phone'];
        theLocale = items['locale'];
        userSex = items['sex'] == 1 ? gendre.Male : gendre.Female;
        if (expiredDate == '') {
          expiredDate = items['expired'].toDate().toString();
          prefs!.setString('expired', expiredDate);
        }
        isExpired = items['expired'].compareTo(Timestamp.now()) < 0;
        setState(() => isRegistered = true);
        _currentPageIndex = isExpired ? 7 : myActivities.length > 0 ? 3 : myGroups.length > 0 ? 2 : 1;
      });
    });
    super.initState();
  }
  @override
  void dispose() async{
    super.dispose();
    closePlatformState();
  }
  @override
  Widget build(BuildContext context) {
    List<String> appTitle = [
      Language.of(context).golferInfo,
      Language.of(context).groups, //"Groups",
      Language.of(context).myGroup, // "My Groups"
      Language.of(context).activities, //"My Activities",
      Language.of(context).golfCourses, //"Golf courses",
      Language.of(context).myScores, //"My Scores",
      Language.of(context).usage,  // "Program Usage"
      Language.of(context).purchase
    ];

    if (expiredDate.length > 0)
      isExpired = Timestamp.fromDate(DateTime.parse(expiredDate.substring(0, 16))).compareTo(Timestamp.now()) < 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(appTitle[_currentPageIndex]),
      ),
      body: Center(
          child: _currentPageIndex == 0 ? registerBody()
              : _currentPageIndex == 1 ? groupBody()
              : _currentPageIndex == 2 ? myGroupBody()
              : _currentPageIndex == 3  ? activityBody()
              : _currentPageIndex == 4  ? golfCourseBody()
              : _currentPageIndex == 5  ? myScoreBody()  
              : _currentPageIndex == 6  ? usageBody() : purchaseBody()
          ),
      drawer: isRegistered ? golfDrawer() : null,
      floatingActionButton: (_currentPageIndex == 1 || _currentPageIndex == 4)
          ? FloatingActionButton(
              onPressed: () => doBodyAdd(_currentPageIndex),
              child: Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Drawer golfDrawer() {
    return Drawer(
      child: ListView(
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(userName),
            accountEmail: Text(userPhone),
            currentAccountPicture: GestureDetector(
                onTap: () {
                  setState(() => isUpdate = true);
                  _currentPageIndex = isExpired ? 7 : 0;
                  Navigator.of(context).pop();
                },
                child: CircleAvatar(backgroundImage: NetworkImage(userSex == gendre.Male ? maleGolfer : femaleGolfer))),
            decoration: BoxDecoration(image: DecorationImage(fit: BoxFit.fill, image: NetworkImage(drawerPhoto))),
            onDetailsPressed: () {
              setState(() => isUpdate = true);
              _currentPageIndex = isExpired ? 7 : 0;
              Navigator.of(context).pop();
            },
          ),
          ListTile(
              title: Text(Language.of(context).groups),
              leading: Icon(Icons.group),
              onTap: () {
                setState(() => _currentPageIndex = isExpired ? 7 : 1);
                Navigator.of(context).pop();
              }),
          ListTile(
              title: Text(Language.of(context).myGroup),
              leading: Icon(Icons.group),
              onTap: () {
                setState(() => _currentPageIndex = isExpired ? 7 : 2);
                Navigator.of(context).pop();
              }),
          ListTile(
              title: Text(Language.of(context).activities),
              leading: Icon(Icons.sports_golf),
              onTap: () {
                setState(() => _currentPageIndex = isExpired ? 7 : 3);
                Navigator.of(context).pop();
              }),
          ListTile(
              title: Text(Language.of(context).golfCourses),
              leading: Icon(Icons.golf_course),
              onTap: () async {
                  setState(() => _currentPageIndex = 4);
                  Navigator.of(context).pop();
              }),
          ListTile(
              title: Text(Language.of(context).myScores),
              leading: Icon(Icons.format_list_numbered),
              onTap: () {
                setState(() => _currentPageIndex = 5);
                Navigator.of(context).pop();
              }),
          ListTile(
              title: Text(Language.of(context).logOut),
              leading: Icon(Icons.exit_to_app),
              onTap: () {
                setState(() {
                  isRegistered = isUpdate = false;
                  userName = '';
                  userPhone = '';
                  golferID = 0;
                  userHandicap= initHandicap;
                  myGroups.clear();
                  myActivities.clear();
                  myScores.clear();
                  _currentPageIndex = isExpired ? 7 : 0;
                });
                Navigator.of(context).pop();
              }),
          ListTile(
              title: Text(Language.of(context).usage),
              leading: Icon(Icons.help),
              onTap: () {
                setState(() => _currentPageIndex = 6);
                Navigator.of(context).pop();
              })
        ],
      ),
    );
  }

  Widget usageBody() {
    return FutureBuilder(
      future: FirebaseStorage.instance.ref().child(Language.of(context).helpImage).getDownloadURL(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const CircularProgressIndicator();
        else
          return Column(children: [Expanded(flex: 2, child: InteractiveViewer(
            //panEnabled: false,
            minScale: 0.8,
            maxScale: 2.5,
            child: Image.network(snapshot.data!.toString())
          ))]);
      }
    );
  }

  ListView registerBody() {
    final logo = Hero(
      tag: 'golfer',
      child: CircleAvatar(backgroundImage: NetworkImage(userSex == gendre.Male ? maleGolfer : femaleGolfer), radius: 120),
    );

    Locale myLocale = Localizations.localeOf(context);
    final golferName = TextFormField(
      initialValue: userName,
//      key: Key(userName),
      showCursor: true,
      onChanged: (String value) => setState(() => userName = value.trim()),
      keyboardType: TextInputType.name,
      style: TextStyle(fontSize: 24),
      decoration: InputDecoration(labelText: Language.of(context).name, hintText: Language.of(context).realName, icon: Icon(Icons.person), border: UnderlineInputBorder()),
    );

    final golferPhone = TextFormField(
      initialValue: userPhone,
//      key: Key(_phone),
      onChanged: (String value) => setState(() => userPhone = value.trim()),
      keyboardType: TextInputType.phone,
      style: TextStyle(fontSize: 24),
      decoration: InputDecoration(labelText: Language.of(context).mobile, icon: Icon(Icons.phone), border: UnderlineInputBorder()),
    );
    final golferSex = Row(children: <Widget>[
      Flexible(
          child: RadioListTile<gendre>(
              title: Text(Language.of(context).male),
              value: gendre.Male,
              groupValue: userSex,
              onChanged: (gendre? value) => setState(() {
                    userSex = value!;
                  }))),
      Flexible(
          child: RadioListTile<gendre>(
              title: Text(Language.of(context).female),
              value: gendre.Female,
              groupValue: userSex,
              onChanged: (gendre? value) => setState(() {
                    userSex = value!;
                  }))),
    ], mainAxisAlignment: MainAxisAlignment.center);
    final loginButton = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton(
            child: Text(
              isUpdate ? Language.of(context).modify : Language.of(context).register,
              style: TextStyle(color: Colors.white, fontSize: 20.0),
            ),
            onPressed: () {
              int uID = 0;
              if (userName != '' && userPhone != '') {
                FirebaseFirestore.instance.collection('Golfers').where('name', isEqualTo: userName).where('phone', isEqualTo: userPhone)
                  .get().then((value) {
                  value.docs.forEach((result) {
                    var items = result.data();
                    golferDoc = result.id;
                    uID = items['uid'];
                    theLocale = items['locale'];
                    expiredDate = items['expired'].toDate().toString();
                    userSex = items['sex'] == 1 ? gendre.Male : gendre.Female;
                    prefs!.setString('expired', expiredDate);
                    golferID = uID;
                    print(userName + '(' + userPhone + ') already registered! ($golferID)');
                    storeMyGroup();
                    storeMyActivities();
                    storeMyScores();
                    isExpired = items['expired'].compareTo(Timestamp.now()) < 0;
                  });
                }).whenComplete(() {
                    if (uID == 0) {
                      if (isUpdate) {
                        FirebaseFirestore.instance.collection('Golfers').doc(golferDoc).update({
                          "name": userName,
                          "phone": userPhone,
                          "sex": userSex == gendre.Male ? 1 : 2,
                        });
                        isUpdate = false;
                      } else {
                        golferID = uuidTime();
                        DateTime expireDate = expiredDate == '' ? DateTime.now().add(Duration(days: 90)) : DateTime.parse(expiredDate);
                        Timestamp expire = Timestamp.fromDate(expireDate);
                        theLocale = myLocale.toString();
                        FirebaseFirestore.instance.collection('Golfers').add({
                          "name": userName,
                          "phone": userPhone,
                          "sex": userSex == gendre.Male ? 1 : 2,
                          "uid": golferID,
                          "expired": expire,
                          "locale": theLocale
                        }).whenComplete(() {
                          if (expiredDate == '') {
                            expiredDate = expire.toDate().toString();
                            prefs!.setString('expired', expiredDate);
                          }
                        });
                      }
                    }
                    _currentPageIndex = isExpired ? 7 : 1;
                    setState(() => isRegistered = true);
                    prefs!.setInt('golferID', golferID);
                  });
                }
            }
        )
    );
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.only(left: 24.0, right: 24.0),
      children: <Widget>[
        SizedBox(height: 8.0),
        logo,
        SizedBox(height: 12.0),
        golferName,
        SizedBox(height: 8.0),
        golferPhone,
        SizedBox(height: 8.0),
        golferSex,
        SizedBox(height: 8.0),
        Visibility(
          visible:isRegistered,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
            Text(Language.of(context).handicap + userHandicap.toString().substring(0, min(userHandicap.toString().length, 5)), style: TextStyle(fontWeight: FontWeight.bold)),
            Text(Language.of(context).expired + expiredDate.substring(0, min(10, expiredDate.length)))
          ])
        ),
        SizedBox(height: 10.0),
        loginButton,
        SizedBox(height: 10.0)
      ],
    );
  }

  Future<bool?> showApplyDialog(int applying) {
    return showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(Language.of(context).hint),
            content: Text(applying == 1 ? Language.of(context).applyWaiting
                      : applying == 0 ? Language.of(context).applyFirst
                      : Language.of(context).applyRejected),
            actions: <Widget>[
              TextButton(child: Text(applying == 0 ? "Apply" : "OK"), onPressed: () => Navigator.of(context).pop(applying == 0)),
              TextButton(child: Text("Cancel"), onPressed: () => Navigator.of(context).pop(false))
            ],
          );
        });
  }

  Widget? groupBody() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('GolferClubs').where('gid', whereNotIn: myGroups.length > 0 ? myGroups : [123]).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const CircularProgressIndicator();
          } else {
            return ListView(
              children: snapshot.data!.docs.map((doc) {
                if ((doc.data()! as Map)["Name"] == null) {
                  return const LinearProgressIndicator();
                } else {
                   _gID = (doc.data()! as Map)["gid"] as int;
                  if (((doc.data()! as Map)["members"] as List).indexOf(golferID) >= 0) {
                    if (myGroups.indexOf(_gID) < 0) {
                      myGroups.add(_gID);
                      storeMyGroup();
                      FirebaseFirestore.instance.collection('ApplyQueue').where('uid', isEqualTo: golferID).where('gid', isEqualTo: _gID).get().then((value) {
                        value.docs.forEach((result) => FirebaseFirestore.instance.collection('ApplyQueue').doc(result.id).delete());
                      });
                    }
                  } /*else if ((doc.data()! as Map)['locale'] != theLocale)
                    return SizedBox(height: 1);*/
                  return Card(
                      child: ListTile(
                    title: Text((doc.data()! as Map)["Name"], style: TextStyle(fontSize: 20)),
                    subtitle: FutureBuilder(
                        future: golferNames((doc.data()! as Map)["managers"] as List),
                        builder: (context, snapshot2) {
                          if (!snapshot2.hasData)
                            return const LinearProgressIndicator();
                          else
                            return Text(Language.of(context).region + (doc.data()! as Map)["region"] + "\n" + Language.of(context).manager + snapshot2.data!.toString() + "\n" + Language.of(context).members + ((doc.data() as Map)["members"] as List<dynamic>).length.toString());
                        }),
                    leading: Image.network(groupPhoto),
                    /*Icon(Icons.group), */
                    trailing: myGroups.indexOf(_gID) >= 0 ? Icon(Icons.keyboard_arrow_right) : Icon(Icons.no_accounts),
                    onTap: () async {
                      _gID = (doc.data()! as Map)["gid"] as int;
                      if (myGroups.indexOf(_gID) >= 0) {
                        Navigator.push(context, groupActPage(doc, golferID, userName, userSex, userHandicap));
                      } else {
                        bool? apply = await showApplyDialog(await isApplying(_gID, golferID));
                        if (apply!) {
                          // fill the apply waiting queue
                          FirebaseFirestore.instance.collection('ApplyQueue').add({
                            "uid": golferID,
                            "gid": _gID,
                            "response": "waiting"
                          }).whenComplete(() => showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text(Language.of(context).hint),
                                  content: Text(Language.of(context).applicationSent),
                                  actions: <Widget>[
                                    TextButton(child: Text("OK"), onPressed: () => Navigator.of(context).pop(true)),
                                  ],
                                );
                              }
                          ));
                        }
                      }
                    },
                    onLongPress: () async {
                      showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text(Language.of(context).groupRemarks),
                              content: Text((doc.data()! as Map)["Remarks"]),
                              actions: <Widget>[
                                TextButton(child: Text("OK"), onPressed: () => Navigator.of(context).pop(true)),
                              ],
                            );
                          });
                    },
                  ));
                }
              }).toList(),
            );
          }
        });
  }

  Widget? myGroupBody() {
    return myGroups.isEmpty ? ListView()
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('GolferClubs').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              } else {
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    if ((doc.data()! as Map)["Name"] == null) {
                      return const LinearProgressIndicator();
                    } else if (!myGroups.contains((doc.data()! as Map)["gid"] as int)) {
                      return const SizedBox.shrink();
                    } else {
                      _gID = (doc.data()! as Map)["gid"] as int;
                      if (((doc.data()! as Map)["members"] as List).indexOf(golferID) < 0) {
                        myGroups.remove(_gID);
                        storeMyGroup();
                        return const LinearProgressIndicator();
                      }
                      return Card(
                        child: ListTile(
                        title: Text((doc.data()! as Map)["Name"], style: TextStyle(fontSize: 20)),
                        subtitle: FutureBuilder(
                            future: golferNames((doc.data()! as Map)["managers"] as List),
                            builder: (context, snapshot2) {
                              if (!snapshot2.hasData)
                                return const LinearProgressIndicator();
                              else
                                return Text(Language.of(context).region + (doc.data()! as Map)["region"] + "\n" + Language.of(context).manager + snapshot2.data!.toString() + "\n" + Language.of(context).members + ((doc.data() as Map)["members"] as List<dynamic>).length.toString());
                            }),
                        leading: Image.network(groupPhoto),
                        /*Icon(Icons.group), */
                        trailing: FutureBuilder(
                            future:notMyActivities(_gID),
                            builder: (context, snapshot3) {
                              if (!snapshot3.hasData)
                                return SizedBox.shrink();
                              else
                                return (snapshot3.data! as int) > 0 ? 
                                  Badge(badgeColor: Colors.green ,badgeContent: Text('${snapshot3.data! as int}'), child: Icon(Icons.keyboard_arrow_right)) :
                                  Icon(Icons.keyboard_arrow_right);
                            }),
                        onTap: () {
                          _gID = (doc.data()! as Map)["gid"] as int;
                          Navigator.push(context, groupActPage(doc, golferID, userName, userSex, userHandicap)).then((value) {
                            setState(() {
                            // update badge
                            });
                          });
                        },
                        onLongPress: () {
                          _gID = (doc.data()! as Map)["gid"] as int;
                          if (((doc.data()! as Map)["managers"] as List).indexOf(golferID) >= 0) {
                            Navigator.push(context, editGroupPage(doc, golferID));
                          } else {
                            showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text((doc.data()! as Map)["Name"]),
                                  content: Text(Language.of(context).quitGroup),
                                  actions: <Widget>[
                                    TextButton(child: Text("Yes"), onPressed: () => Navigator.of(context).pop(true)),
                                    TextButton(child: Text("No"), onPressed: () => Navigator.of(context).pop(false))
                                  ],
                                );
                              }
                            ).then((value) {
                              if (value!) {
                                removeMemberAllActivities(_gID, golferID);
                                removeMember(_gID, golferID);
                                myGroups.remove(_gID);
                                storeMyGroup();
                                setState(() {});
                              }
                            });
                          }
                        },
                      ));
                    }
                  }).toList(),
                );
              }
            });
  }

  Widget? golfCourseBody() {
    return FutureBuilder(
      future: getOrderedCourse(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          locationGranted();
          return const CircularProgressIndicator();
        } else {
          List<CourseItem> courses = snapshot.data as List<CourseItem>;         
          sortByDistance(courses);
          return ListView.builder(
            itemCount: courses.length,
            itemBuilder: (BuildContext context2, int i) {
              return Card(child: ListTile(
                leading: Image.network(courses[i].photo),
                title: Text(courses[i].name),
                subtitle: Text((courses[i].zones* 9).toString() + ' Holes'),
                trailing: Icon(Icons.keyboard_arrow_right),
                onTap: () async {
                  if (courses[i].zones > 2) {
                    List zones = await selectZones(context2, courses[i].doc);
                    if (zones.isNotEmpty) 
                      Navigator.push(context2, newScorePage(courses[i].doc, userName, zone0: zones[0], zone1: zones[1]));               
                  } else
                      Navigator.push(context2, newScorePage(courses[i].doc, userName));
                }
              ));
            }
          ); 
        }
      }
    );
  }

  ListView myScoreBody() {
    int cnt = myScores.length > 10 ? 10 : myScores.length;
    userHandicap = 0;

    List<int> scoreRow(List pars, List scores){      
      int eg = 0, bd =0, par = 0, bg = 0, db = 0, mm = 0;
      for (var i=0; i < pars.length; i++) {
        if (scores[i] == pars[i]) par++;
        else if (scores[i] == pars[i] + 1) bg++;
        else if (scores[i] == pars[i] + 2) db++;
        else if (scores[i] == pars[i] - 1) bd++;
        else if (scores[i] == pars[i] - 2) eg++;
        else mm++;
      }
      return [eg, bd, par, bg, db, mm];
    }
    List parRows = [
      Emoji.byName('eagle')!.char, 
      Emoji.byName('dove')!.char, 
      Emoji.byName('person golfing')!.char, 
      Emoji.byName('index pointing up')!.char,
      Emoji.byName('victory hand')!.char,
      Emoji.byName('face exhaling')!.char
    ];
    return ListView.builder(
      itemCount: myScores.length,
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (BuildContext context, int i) {
        if (i < cnt) userHandicap += myScores[i]['handicap'];
        if ((i + 1) == cnt) {
          userHandicap = (userHandicap / cnt) * 0.9;
          prefs!.setDouble('handicap', userHandicap);
        }
        return ListTile(
          leading: CircleAvatar(child: Text(myScores[i]['total'].toString(), style: TextStyle(fontWeight: FontWeight.bold))), 
          title: Text(myScores[i]['date'] + ' ' + myScores[i]['course'], style: TextStyle(fontWeight: FontWeight.bold)), 
          subtitle: Text(parRows.toString() + ': ' + scoreRow(myScores[i]['pars'], myScores[i]['scores']).toString())
        );
      },
    );
  }

  void doBodyAdd(int index) async {
    switch (index) {
      case 1:
        Navigator.push(context, newGroupPage(golferID, theLocale)).then((ret) {
          if (ret ?? false) setState(() => index = 1);
        });
        break;
      case 4:
        Navigator.push(context, newGolfCoursePage()).then((ret) {
          if (ret ?? false) setState(() => index = 4);
        });
        break;
    }
  }
}
