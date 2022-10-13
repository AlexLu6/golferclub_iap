import 'package:flutter/cupertino.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:editable/editable.dart';
import 'package:flutter_material_pickers/flutter_material_pickers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emojis/emoji.dart';
import 'dataModel.dart';
import 'createPage.dart';
import 'editable2.dart';
import 'course_order.dart';
import 'locale/language.dart';

String netPhoto = 'https://wallpaper.dog/large/5514437.jpg';
Widget activityBody() {
  Timestamp deadline = Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
  var allActivities = [];
  return myActivities.isEmpty ? ListView()
      : StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('ClubActivities').orderBy('teeOff').snapshots(), //.where(FieldPath.documentId, whereIn: myActivities)
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return CircularProgressIndicator();
            } else {
              return ListView(
                children: snapshot.data!.docs.map((doc) {
                if ((doc.data()! as Map)["teeOff"] == null) {
                  return LinearProgressIndicator();
                } else if (myActivities.indexOf(doc.id) < 0) {
                  return SizedBox.shrink();
                } else if ((doc.data()! as Map)["teeOff"].compareTo(deadline) < 0) {
                  myActivities.remove(doc.id);
                  storeMyActivities();
                  return SizedBox.shrink();
                } else {
                  allActivities.add(doc.id);
                  return Card(
                      child: ListTile(
                          title: FutureBuilder(
                              future: courseName((doc.data()! as Map)['cid'] as int),
                              builder: (context, snapshot2) {
                                if (!snapshot2.hasData)
                                  return const LinearProgressIndicator();
                                else
                                  return Text(snapshot2.data!.toString(), style: TextStyle(fontSize: 20));
                              }),
                          subtitle: Text(Language.of(context).teeOff + ((doc.data()! as Map)['teeOff']).toDate().toString().substring(0, 16) + '\n' + 
                                        Language.of(context).max + (doc.data()! as Map)['max'].toString() + ' ' + 
                                        Language.of(context).now + ((doc.data()! as Map)['golfers'] as List).length.toString() + " " + 
                                        Language.of(context).fee + (doc.data()! as Map)['fee'].toString()),
                          leading: FutureBuilder(
                              future: coursePhoto((doc.data()! as Map)['cid'] as int),
                              builder: (context, snapshot3) {
                                if (!snapshot3.hasData)
                                  return const CircularProgressIndicator();
                                else 
                                  return Image.network(snapshot3.data!.toString());
                              }),
                          trailing: Icon(Icons.keyboard_arrow_right),
                          onTap: () async {
                          
                            Navigator.push(context, ShowActivityPage(doc, golferID, await groupName((doc.data()! as Map)['gid'] as int)!, await isManager((doc.data()! as Map)['gid'] as int, golferID), userHandicap)).then((value) async {
                              var glist = doc.get('golfers');
                              if (value == -1) {
                                myActivities.remove(doc.id);
                                storeMyActivities();
                                glist.removeWhere((item) => item['uid'] == golferID);
                                var subGroups = doc.get('subgroups');
                                for (int i = 0; i < subGroups.length; i++) {
                                  for (int j = 0; j < (subGroups[i] as Map).length; j++) {
                                    if ((subGroups[i] as Map)[j.toString()] == golferID) {
                                      for (; j<(subGroups[i] as Map).length - 1; j++)
                                        (subGroups[i] as Map)[j.toString()] = (subGroups[i] as Map)[(j+1).toString()];
                                      (subGroups[i] as Map).remove(j.toString());
                                    }                                   
                                  }
                                }
                                FirebaseFirestore.instance.collection('ClubActivities').doc(doc.id).update({
                                  'golfers': glist,
                                  'subgroups': subGroups
                                });
                                print(myActivities);
//                                setState(() {});
                              } else if (value == 1) {
                                glist.add({
                                  'uid': golferID,
                                  'name': userName + ((userSex == gendre.Female) ? Language.of(context).femaleNote : ''),
                                  'scores': []
                                });
                                myActivities.add(doc.id);
                                storeMyActivities();
                                FirebaseFirestore.instance.collection('ClubActivities').doc(doc.id).update({
                                  'golfers': glist
                                });                                
                              } else if (myActivities.length != allActivities.length) {
                                  myActivities = allActivities;
                                  storeMyActivities();
                              }
                            });
                          }));
                }
              }).toList());
            }
          }
        );
}

ShowActivityPage showActivityPage(var activity, int uId, String title, bool editable, double handicap) {
  return ShowActivityPage(activity, uId, title, editable, handicap);
}

class ShowActivityPage extends MaterialPageRoute<int> {
  ShowActivityPage(var activity, int uId, String title, bool editable, double handicap)
      : super(builder: (BuildContext context) {
          bool alreadyIn = false, scoreReady = false, scoreDone = false, isBackup = false;
          String uName = '';
          int uIdx = 0;
          var rows = [];

          List buildRows() {
            var oneRow = {};
            int idx = 0;

            for (var e in activity.data()!['golfers']) {
              if (idx % 4 == 0) {
                oneRow = Map();
                if (idx >= (activity.data()!['max'] as int))
                  oneRow['row'] = Language.of(context).waiting;
                else
                  oneRow['row'] = (idx >> 2) + 1;
                oneRow['c1'] = e['name'];
                oneRow['c2'] = '';
                oneRow['c3'] = '';
                oneRow['c4'] = '';
              } else if (idx % 4 == 1)
                oneRow['c2'] = e['name'];
              else if (idx % 4 == 2)
                oneRow['c3'] = e['name'];
              else if (idx % 4 == 3) {
                oneRow['c4'] = e['name'];
                rows.add(oneRow);
              }
              idx++;
              if (idx == (activity.data()!['max'] as int)) {
                if (idx % 4 != 0)
                  rows.add(oneRow);
                while (idx % 4 != 0) idx++;
              }
            }
            if ((idx % 4) != 0)
              rows.add(oneRow);
            else if (idx == 0) {
              oneRow['row'] = '1';
              oneRow['c1'] = oneRow['c2'] = oneRow['c3'] = oneRow['c4'] = '';
              rows.add(oneRow);
            }
            return rows;
          }

          List buildScoreRows() {
            var scoreRows = [];
            int idx = 1;    
            for (var e in activity.data()!['golfers']) {
              if ((e['scores'] as List).length > 0) {
                int eg = 0, bd =0, par = 0, bg = 0, db = 0;
                List pars = e['pars'] as List;              
                List scores = e['scores'] as List;
                for (var ii=0; ii < pars.length; ii++) {
                  if (scores[ii] == pars[ii]) par++;
                  else if (scores[ii] == pars[ii] + 1) bg++;
                  else if (scores[ii] == pars[ii] + 2) db++;
                  else if (scores[ii] == pars[ii] - 1) bd++;
                  else if (scores[ii] == pars[ii] - 2) eg++;
                }
                String net = e['net'].toString();
                scoreRows.add({
                  'rank': idx,
                  'total': e['total'],
                  'name': e['name'],
                  'net': net.substring(0, min(net.length, 5)),
                  'EG' : eg,
                  'BD' : bd,
                  'PAR' : par,
                  'BG' : bg,
                  'DB' : db
                });
                idx++;
              }
            }
            scoreRows.sort((a, b) => a['total'] - b['total']);
            for (idx = 0; idx < scoreRows.length; idx++)
              scoreRows[idx]['rank'] = idx + 1;
            return scoreRows;
          }

          bool teeOffPass = activity.data()!['teeOff'].compareTo(Timestamp.now()) < 0;
          Map course = {};
          void updateScore() {
            FirebaseFirestore.instance.collection('ClubActivities').doc(activity.id).get().then((value) {
              var glist = value.get('golfers');
              glist[uIdx]['pars'] = myScores[0]['pars'];
              glist[uIdx]['scores'] = myScores[0]['scores'];
              glist[uIdx]['total'] = myScores[0]['total'];
              glist[uIdx]['net'] = myScores[0]['total'] - handicap;
              FirebaseFirestore.instance.collection('ClubActivities').doc(activity.id).update({
                'golfers': glist
              }).whenComplete(() => Navigator.of(context).pop(0));
            });           
          }

          // prepare parameters
          int eidx = 0;
          for (var e in activity.data()!['golfers']) {
            if (e['uid'] as int == uId) {
              uIdx = eidx;
              alreadyIn = true;
              isBackup = eidx >= (activity.data()!['max'] as int);
              uName = e['name'];
              if (myActivities.indexOf(activity.id) < 0) {
                myActivities.add(activity.id);
                storeMyActivities();
              }
            }
            if ((e['scores'] as List).length > 0) {
              scoreReady = true;
              if (e['uid'] as int == uId) 
                scoreDone = true;              
            }
            eidx++;
          }

          return Scaffold(
              appBar: AppBar(title: Text(title), elevation: 1.0),
              body: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                return Container(
                  decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(netPhoto), fit: BoxFit.cover)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                  const SizedBox(height: 10.0),
                  Text(Language.of(context).teeOff + activity.data()!['teeOff'].toDate().toString().substring(0, 16) + ' ' + Language.of(context).fee + activity.data()!['fee'].toString(), style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 10.0),
                  FutureBuilder(
                      future: courseBody(activity.data()!['cid'] as int),
                      builder: (context, snapshot2) {
                        if (!snapshot2.hasData)
                          return const LinearProgressIndicator();
                        else {
                          course = snapshot2.data! as Map;
                          return Text(course['name'] + " " + Language.of(context).max + activity.data()!['max'].toString(), style: TextStyle(fontSize: 20));
                        }
                      }),
                  const SizedBox(height: 10.0),
                  Visibility(
                    visible: !scoreReady,
                    child: Flexible(
                      child: Editable(
                      borderColor: Colors.black,
                      tdStyle: TextStyle(fontSize: 14),
                      trHeight: 16,
                      tdAlignment: TextAlign.center,
                      thAlignment: TextAlign.center,
                      columnRatio: 0.2,
                      columns: [
                        {"title": Language.of(context).tableGroup, 'index': 1, 'key': 'row', 'editable': false, 'widthFactor': 0.15},
                        {"title": "A", 'index': 2, 'key': 'c1', 'editable': false},
                        {"title": "B", 'index': 3, 'key': 'c2', 'editable': false},
                        {"title": "C", 'index': 4, 'key': 'c3', 'editable': false},
                        {"title": "D", 'index': 5, 'key': 'c4', 'editable': false}
                      ],
                      rows: buildRows(),
                    ))
                  ),
                  Text(Language.of(context).actRemarks + activity.data()!['remarks']),
                  const SizedBox(height: 4.0),
                  Visibility(
                    visible: ((activity.data()!['golfers'] as List).length > 4) && alreadyIn && !isBackup && !scoreReady,
                    child: ElevatedButton(
                      child: Text(Language.of(context).subGroup),
                      onPressed: () {
                        Navigator.push(context, SubGroupPage(activity, uId)).then((value) {
                          if (value ?? false) Navigator.of(context).pop(0);
                        });
                      }
                    )
                  ),
                  const SizedBox(height: 4.0),
                  Visibility(
                    visible: scoreReady,
                    child : Flexible(
                      child: Editable(
                      borderColor: Colors.black,
                      tdStyle: TextStyle(fontSize: 14),
                      trHeight: 16,
                      tdAlignment: TextAlign.center,
                      thAlignment: TextAlign.center,
                      columnRatio: 0.1,
                      columns: [
                        {'title': Language.of(context).rank, 'index': 1, 'key': 'rank', 'editable': false},
                        {'title': Language.of(context).total, 'index': 2, 'key': 'total', 'editable': false, 'widthFactor': 0.13},
                        {'title': Language.of(context).name, 'index': 3, 'key': 'name', 'editable': false, 'widthFactor': 0.2},
                        {'title': Language.of(context).net, 'index': 4, 'key': 'net', 'editable': false, 'widthFactor': 0.15},
                        {'title': '${Emoji.byName('dove')!.char}', 'index': 5, 'key': 'BD', 'editable': false},
                        {'title': '${Emoji.byName('person golfing')!.char}', 'index': 6, 'key': 'PAR', 'editable': false},
                        {'title': '${Emoji.byName('index pointing up')!.char}', 'index': 7, 'key': 'BG', 'editable': false},
                        {'title': '${Emoji.byName('victory hand')!.char}', 'index': 8, 'key': 'DB', 'editable': false},
                        {'title': '${Emoji.byName('eagle')!.char}', 'index': 9, 'key': 'EG', 'editable': false},      
                      ],
                      rows: buildScoreRows(),
                    ))
                  ),
                  Visibility(
                    visible: teeOffPass && alreadyIn && !isBackup && !scoreDone,
                    child : ElevatedButton(
                      child: Text(Language.of(context).enterScore),
                      onPressed: () async {
                          if ((course["zones"]).length > 2) {
                            List zones = await selectZones(context, course);
                            if (zones.isNotEmpty)
                              Navigator.push(context, newScorePage(course, uName, zone0: zones[0], zone1: zones[1])).then((value) {
                                if (value ?? false) updateScore();
                              });
                          } else {
                            Navigator.push(context, newScorePage(course, uName)).then((value) {
                              if (value ?? false) updateScore();
                            });
                          }
                      }
                    )
                  ),
                  Visibility(
                    visible: !teeOffPass && alreadyIn,
                    child: ElevatedButton(
                      child: Text(Language.of(context).cancel),
                      onPressed: () => Navigator.of(context).pop(-1)
                    )
                  ),
                  Visibility(
                    visible: !teeOffPass && !alreadyIn,
                    child: ElevatedButton(
                      child: Text(Language.of(context).apply),
                      onPressed: () => Navigator.of(context).pop(1)
                    )
                  ),
                  const SizedBox(height: 4.0)
                ]));
              }),
              floatingActionButton: Visibility(
                  visible: editable,
                  child: FloatingActionButton(
                      onPressed: () {
                        // modify activity info
                        Navigator.push(context, _EditActivityPage(activity, course['name'])).then((value) {
                          if (value ?? false) Navigator.of(context).pop(0);
                        });
                      },
                      child: const Icon(Icons.edit),
                  )
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.endTop);
        });
}

_NewActivityPage newActivityPage(bool isMan, int gid, int uid) {
  return _NewActivityPage(isMan, gid, uid);
}

class _NewActivityPage extends MaterialPageRoute<bool> {
  _NewActivityPage(bool isMan, int gid, int uid)
      : super(builder: (BuildContext context) {
          String _courseName = '', _remarks = '';
          var _selectedCourse;
          DateTime _selectedDate = DateTime.now();
          bool _includeMe = true;
          int _fee = 2500, _max = 4;
          var activity = FirebaseFirestore.instance.collection('ClubActivities');

          return Scaffold(
              appBar: AppBar(title: Text(Language.of(context).createNewActivity), elevation: 1.0),
              body: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                return Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(height: 12.0),
                  Flexible(
                    child: Row(children: <Widget>[
                      FutureBuilder(
                        future: getOrderedCourse(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            locationGranted();
                            return const CircularProgressIndicator();
                          } else {
                            List<CourseItem> courses = snapshot.data as List<CourseItem>;
                            sortByDistance(courses);
                            return ElevatedButton(
                              child: Text(Language.of(context).golfCourses),
                              onPressed: () {
                                showMaterialScrollPicker<CourseItem>(
                                  context: context,
                                  title: Language.of(context).selectCourse,
                                  items: courses,
                                  showDivider: false,
                                  selectedItem: courses[0], //_selectedCourse,
                                  onChanged: (value) => setState(() => _selectedCourse = value),
                                ).then((value) => setState(() => _courseName = value == null ? '' : value.toString()));
                              }
                            );
                          }
                        }
                      ),
                    const SizedBox(width: 5),
                    Flexible(
                        child: TextFormField(
                      initialValue: _courseName,
                      key: Key(_courseName),
                      showCursor: true,
                      onChanged: (String value) => setState(() => print(_courseName = value)),
                      //keyboardType: TextInputType.name,
                      decoration: InputDecoration(labelText: Language.of(context).courseName, border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 5)
                  ])),
                  const SizedBox(height: 12),
                  Flexible(
                      child: Row(children: <Widget>[
                    ElevatedButton(
                        child: Text(Language.of(context).teeOff),
                        onPressed: () {
                          showMaterialDatePicker(
                            context: context,
                            title: Language.of(context).pickDate,
                            selectedDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 180)),
                            //onChanged: (value) => setState(() => _selectedDate = value),
                          ).then((date) {
                            if (date != null) showMaterialTimePicker(
                              context: context, 
                              title: Language.of(context).pickTime, 
                              selectedTime: TimeOfDay.now()).then((time) => 
                                setState(() => _selectedDate = DateTime(date.year, date.month, date.day, time!.hour, time.minute)))
                              ;
                          });
                        }),
                    const SizedBox(width: 5),
                    Flexible(
                        child: TextFormField(
                      initialValue: _selectedDate.toString().substring(0, 16),
                      key: Key(_selectedDate.toString().substring(0, 16)),
                      showCursor: true,
                      onChanged: (String? value) => _selectedDate = DateTime.parse(value!),
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(labelText: Language.of(context).teeOffTime, border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 5)
                  ])),
                  const SizedBox(height: 12),
                  Flexible(
                      child: Row(children: <Widget>[
                    const SizedBox(width: 5),
                    Flexible(
                        child: TextFormField(
                      initialValue: _max.toString(),
                      showCursor: true,
                      onChanged: (String value) => setState(() => _max = int.parse(value)),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: Language.of(context).max, icon: Icon(Icons.group), border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 5),
                    Flexible(
                        child: TextFormField(
                      initialValue: _fee.toString(),
                      showCursor: true,
                      onChanged: (String value) => setState(() => _fee = int.parse(value)),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: Language.of(context).fee, icon: Icon(Icons.money), border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 5)
                  ])),
                  const SizedBox(height: 12.0),
                  TextFormField(
                    showCursor: true,
                    initialValue: _remarks,
                    onChanged: (String value) => setState(() => _remarks = value),
                    //keyboardType: TextInputType.name,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: Language.of(context).actRemarks, icon: Icon(Icons.edit_note), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Row(children: <Widget>[
                    const SizedBox(width: 5),
                    Checkbox(value: _includeMe, onChanged: (bool? value) => setState(() => _includeMe = value!)),
                    const SizedBox(width: 5),
                    const Text('Include myself')
                  ])),
                  const SizedBox(height: 12.0),
                  ElevatedButton(
                      child: Text(Language.of(context).create, style: TextStyle(fontSize: 24)),
                      onPressed: () async {
                        if (_courseName != '') {
                          activity.add({
                            'gid': gid,
                            "cid": _selectedCourse.toID(),
                            "teeOff": Timestamp.fromDate(_selectedDate),
                            "max": _max,
                            "fee": _fee,
                            "remarks": _remarks,
                            'subgroups': [],
                            "golfers": _includeMe ? [{"uid": uid, "name": userName + ((userSex == gendre.Female) ? Language.of(context).femaleNote : ''), "scores": []}] : []
                          }).then((value) {
                            if (_includeMe) {
                              myActivities.add(value.id);
                              storeMyActivities();
                            }
                            Navigator.of(context).pop(true);
                          });
                        }
                      })
                ]);
              }));
        });
}

class _EditActivityPage extends MaterialPageRoute<bool> {
  _EditActivityPage(var actDoc, String _courseName)
      : super(builder: (BuildContext context) {
          String _remarks = (actDoc.data()! as Map)['remarks'];
          int _fee = (actDoc.data()! as Map)['fee'], _max = (actDoc.data()! as Map)['max'];
          DateTime _selectedDate = (actDoc.data()! as Map)['teeOff'].toDate();
          List<NameID> golfers = [];
          var _selectedGolfer;
          var blist = [];

          ((actDoc.data()! as Map)['golfers'] as List).forEach((element) {
            blist.add(element['uid']);
          });
          if (blist.length > 0)
            FirebaseFirestore.instance.collection('Golfers').get().then((value) {
              value.docs.forEach((result) {
                var items = result.data();
                int uid = items['uid'] as int;
                if (blist.indexOf(uid) >= 0)
                  golfers.add(NameID(items['name'] + '(' + items['phone'] + ')', items['uid'] as int));
              });
            });

          return Scaffold(
              appBar: AppBar(title: Text(Language.of(context).editActivity), elevation: 1.0),
              body: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                return Column(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                  const SizedBox(height: 12),
                  Text(Language.of(context).courseName + _courseName, style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 12),
                  Flexible(
                      child: Row(children: <Widget>[
                    ElevatedButton(
                        child: Text(Language.of(context).teeOff),
                        onPressed: () {
                          showMaterialDatePicker(
                            context: context,
                            title: Language.of(context).pickDate,
                            selectedDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 180)),
                            //onChanged: (value) => setState(() => _selectedDate = value),
                          ).then((date) {
                            if (date != null) showMaterialTimePicker(
                              context: context, 
                              title: Language.of(context).pickTime, 
                              selectedTime: TimeOfDay.now()).then((time) => 
                                setState(() => _selectedDate = DateTime(date.year, date.month, date.day, time!.hour, time.minute))
                              );
                          });
                        }),
                    const SizedBox(width: 5),
                    Flexible(
                        child: TextFormField(
                      initialValue: _selectedDate.toString().substring(0, 16),
                      key: Key(_selectedDate.toString().substring(0, 16)),
                      showCursor: true,
                      onChanged: (String? value) => _selectedDate = DateTime.parse(value!),
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(labelText: Language.of(context).teeOffTime, border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 5)
                  ])),
                  const SizedBox(height: 12),
                  Flexible(
                      child: Row(children: <Widget>[
                    const SizedBox(width: 5),
                    Flexible(
                        child: TextFormField(
                      initialValue: _max.toString(),
                      showCursor: true,
                      onChanged: (String value) => _max = int.parse(value),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: Language.of(context).max, icon: Icon(Icons.group), border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 5),
                    Flexible(
                        child: TextFormField(
                      initialValue: _fee.toString(),
                      showCursor: true,
                      onChanged: (String value) => _fee = int.parse(value),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: Language.of(context).fee, icon: Icon(Icons.money), border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 5)
                  ])),
                  const SizedBox(height: 12),
                  TextFormField(
                    showCursor: true,
                    initialValue: _remarks,
                    onChanged: (String value) => _remarks = value,
                    //keyboardType: TextInputType.name,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: Language.of(context).actRemarks, icon: Icon(Icons.edit_note), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
                    ElevatedButton(
                      child: Text(Language.of(context).modify, style: TextStyle(fontSize: 18)),
                      onPressed: () async {
                        FirebaseFirestore.instance.collection('ClubActivities').doc(actDoc.id).update({
                          "teeOff": Timestamp.fromDate(_selectedDate),
                          "max": _max,
                          "fee": _fee,
                          "remarks": _remarks,
                        }).then((value) {
                          Navigator.of(context).pop(true);
                        });
                      }
                    ),
                    Visibility(
                      visible: blist.length > 0,
                      child: ElevatedButton(
                        child: Text(Language.of(context).kickMember, style: TextStyle(fontSize: 18)),
                        onPressed: () {
                          showMaterialScrollPicker<NameID>(
                            context: context,
                            title: Language.of(context).selectKickMember,
                            items: golfers,
                            showDivider: false,
                            selectedItem: golfers[0],
                            onChanged: (value) => setState(() => _selectedGolfer = value),
                          ).then((value) {
                            if (_selectedGolfer != null) 
                              removeGolferActivity(actDoc, _selectedGolfer.toID());
                            Navigator.of(context).pop(true);
                          });
                        }
                      )
                    )
                  ])
                ]);
              }));
        });
}

Future<List> selectZones(BuildContext context, Map course, {int zone0 = 0, int zone1 = 1}) {
  bool? _zone0 = true, _zone1 = true, _zone2 = false, _zone3 = false;
  return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(Language.of(context).select2Courses),
            actions: [
              CheckboxListTile(
                  value: _zone0,
                  title: Text(course["zones"][0]['name']),
                  onChanged: (bool? value) {
                    setState(() => _zone0 = value);
                  }),
              CheckboxListTile(
                  value: _zone1,
                  title: Text(course["zones"][1]['name']),
                  onChanged: (bool? value) {
                    setState(() => _zone1 = value);
                  }),
              CheckboxListTile(
                  value: _zone2,
                  title: Text(course["zones"][2]['name']),
                  onChanged: (bool? value) {
                    setState(() => _zone2 = value);
                  }),
              (course["zones"]).length == 3
                  ? SizedBox(height: 6)
                  : CheckboxListTile(
                      value: _zone3,
                      title: Text(course["zones"][3]['name']),
                      onChanged: (bool? value) {
                        setState(() => _zone3 = value);
                      }),
              Row(children: [
                TextButton(child: Text("OK"), onPressed: () => Navigator.of(context).pop(true)),
                TextButton(child: Text("Cancel"), onPressed: () => Navigator.of(context).pop(false))
              ])
            ],
          );
        });
      }).then((value) {
    int zone0, zone1;
    zone0 = _zone0! ? 0 : _zone1! ? 1 : 2;
    zone1 = _zone3! ? 3 : _zone2! ? 2 : 1;
    if (value)
      return [zone0, zone1];
    return [];
  });
}

_NewScorePage newScorePage(Map course, String golfer, {int zone0 = 0, int zone1 = 1}) {
  return _NewScorePage(course, golfer, zone0, zone1);
}

class _NewScorePage extends MaterialPageRoute<bool> {
  _NewScorePage(Map course, String golfer, int zone0, int zone1)
      : super(builder: (BuildContext context) {
          final _editableKey = GlobalKey<Editable2State>();
          var columns = [
            {'title': 'Out', 'index': 0, 'key': 'zone1', 'editable': false},
            {'title': "Par", 'index': 1, 'key': 'par1', 'editable': false},
            {'title': " ", 'index': 2, 'key': 'score1', 'widthFactor': 0.17},
            {'title': 'In', 'index': 3, 'key': 'zone2', 'editable': false},
            {'title': "Par", 'index': 4, 'key': 'par2', 'editable': false},
            {'title': " ", 'index': 5, 'key': 'score2', 'widthFactor': 0.17}
          ];
          var rows = [
            {'zone1': '1', 'par1': '4', 'score1': '', 'zone2': '10', 'par2': '4', 'score2': ''},
            {'zone1': '2', 'par1': '4', 'score1': '', 'zone2': '11', 'par2': '4', 'score2': ''},
            {'zone1': '3', 'par1': '4', 'score1': '', 'zone2': '12', 'par2': '4', 'score2': ''},
            {'zone1': '4', 'par1': '4', 'score1': '', 'zone2': '13', 'par2': '4', 'score2': ''},
            {'zone1': '5', 'par1': '4', 'score1': '', 'zone2': '14', 'par2': '4', 'score2': ''},
            {'zone1': '6', 'par1': '4', 'score1': '', 'zone2': '15', 'par2': '4', 'score2': ''},
            {'zone1': '7', 'par1': '4', 'score1': '', 'zone2': '16', 'par2': '4', 'score2': ''},
            {'zone1': '8', 'par1': '4', 'score1': '', 'zone2': '17', 'par2': '4', 'score2': ''},
            {'zone1': '9', 'par1': '4', 'score1': '', 'zone2': '18', 'par2': '4', 'score2': ''},
            {'zone1': 'Sum', 'par1': '', 'score1': '', 'zone2': 'Sum', 'par2': '4', 'score2': ''}
          ];
          List<int> pars = List.filled(18, 0), scores = List.filled(18, 0);
          int sum1 = 0, sum2 = 0;
          int tpars = 0;
          List buildColumns() {
            columns[0]['title'] = course['zones'][zone0]['name'];
            columns[3]['title'] = course['zones'][zone1]['name'];
            return columns;
          }

          List buildRows() {
            int idx = 0, sum = 0;
            tpars = 0;
            (course['zones'][zone0]['holes']).forEach((par) {
              rows[idx]['par1'] = par.toString();
              sum += int.parse(par);
              pars[idx] = int.parse(par);
              tpars += pars[idx];
              idx++;
            });
            rows[idx]['par1'] = sum.toString();
            idx = sum = 0;
            (course['zones'][zone1]['holes']).forEach((par) {
              rows[idx]['par2'] = par.toString();
              sum += int.parse(par);
              pars[idx + 9] = int.parse(par);
              tpars += pars[idx];
              idx++;
            });
            rows[idx]['par2'] = sum.toString();
            return rows;
          }

          return Scaffold(
              appBar: AppBar(title: Text(Language.of(context).enterScore), elevation: 1.0),
              body: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                return Container(
                  decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(netPhoto), fit: BoxFit.cover)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  const SizedBox(height: 10.0),
                  Row(
                    children: <Widget>[
                      Text(course['region'] + ' ' + course['name'], style: TextStyle(fontSize: 18)),
                      Text(Language.of(context).name + golfer, style: TextStyle(fontSize: 18))
                    ],
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  ),
                  const SizedBox(height: 10.0),
                  Flexible(
                      child: Editable2(
                          key: _editableKey,
                          borderColor: Colors.black,
                          tdStyle: TextStyle(fontSize: 14),
                          trHeight: 16,
                          tdAlignment: TextAlign.center,
                          thAlignment: TextAlign.center,
                          columnRatio: 0.15,
                          columns: buildColumns(),
                          rows: buildRows(),
                          onSubmitted: (value) {
                            sum1 = sum2 = 0;
                            _editableKey.currentState!.editedRows.forEach((element) {
                              if (element['row'] != 9) {
                                sum1 += int.parse(element['score1'] ?? '0');
                                sum2 += int.parse(element['score2'] ?? '0');
                                scores[element['row']] = int.parse(element['score1'] ?? '0');
                                scores[element['row'] + 9] = int.parse(element['score2'] ?? '0');
                              }
                            });
                            setState(() {});
                          })),
                  Text(Language.of(context).scoreNote, style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 6.0),
                  (sum1 + sum2) == 0 ? const SizedBox(height: 6.0) : Text(Language.of(context).total + ': ' + (sum1 + sum2).toString(), style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 6.0),
                  Center(
                      child: ElevatedButton(
                          child: Text(Language.of(context).store, style: TextStyle(fontSize: 20)),
                          onPressed: () {
                            bool complete = scores.length > 0;
                            scores.forEach((element) {
                              if (element == 0) complete = false;
                            });
                            if (complete) {
                              myScores.insert(0, {
                                'date': DateTime.now().toString().substring(0, 11),
                                'course': course['name'] + (course['zones'].length > 2 ? '(${course['zones'][zone0]['name']}, ${course['zones'][zone1]['name']})' : ''),
                                'pars': pars,
                                'scores': scores,
                                'total': sum1 + sum2,
                                'handicap': (sum1 + sum2) - tpars > 0 ? (sum1 + sum2) - tpars : 0
                              });
                              storeMyScores();
                              Navigator.of(context).pop(true);
                            }
                          })),
                  const SizedBox(height: 6.0)
                ]));
              }));
        });
}
