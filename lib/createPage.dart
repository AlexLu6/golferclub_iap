import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:editable/editable.dart';
import 'package:flutter_material_pickers/flutter_material_pickers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:charcode/charcode.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'dataModel.dart';
import 'locale/language.dart';
import 'activity.dart';

_NewGroupPage newGroupPage(int golferID, String locale) {
  return _NewGroupPage(golferID, locale);
}

class _NewGroupPage extends MaterialPageRoute<bool> {
  _NewGroupPage(int golferID, String _locale)
      : super(builder: (BuildContext context) {
          String _groupName = '', _region = '', _remarks = '';
          return Scaffold(
              appBar: AppBar(title: Text(Language.of(context).createNewGolfGroup), elevation: 1.0),
              body: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                return Center(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                  TextFormField(
                    showCursor: true,
                    onChanged: (String value) => setState(() => _groupName = value.trim()),
                    //keyboardType: TextInputType.name,
                    decoration: InputDecoration(labelText: Language.of(context).groupName, icon: Icon(Icons.group), border: UnderlineInputBorder()),
                  ),
                  TextFormField(
                    showCursor: true,
                    onChanged: (String value) => setState(() => _region = value.trim()),
                    //keyboardType: TextInputType.name,
                    decoration: InputDecoration(labelText: Language.of(context).groupActRegion, icon: Icon(Icons.place), border: UnderlineInputBorder()),
                  ),
                  const SizedBox(height: 24.0),
                  TextFormField(
                    showCursor: true,
                    onChanged: (String value) => setState(() => _remarks = value),
                    //keyboardType: TextInputType.name,
                    maxLines: 5,
                    decoration: InputDecoration(labelText: Language.of(context).groupRemarks, icon: Icon(Icons.edit_note), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                      child: Text(Language.of(context).create, style: TextStyle(fontSize: 24)),
                      onPressed: () {
                        int gID = uuidTime();
                        if (_groupName != '' && _region != '') {
                          FirebaseFirestore.instance.collection('GolferClubs').add({
                            "Name": _groupName,
                            "region": _region,
                            "Remarks": _remarks,
                            "managers": [golferID],
                            "members": [golferID],
                            "locale": _locale,
                            "gid": gID
                          });
                          myGroups.add(gID);
                          storeMyGroup();
                          Navigator.of(context).pop(true);
                        }
                      })
                ]));
              }));
        });
}

_GroupActPage groupActPage(var groupDoc, int uID, String uName, gendre uSex, double uHandicap) {
  return _GroupActPage(groupDoc, uID, uName, uSex, uHandicap);
}

class _GroupActPage extends MaterialPageRoute<bool> {
  _GroupActPage(var groupDoc, int uID, String _name, gendre _sex, double _handicap)
      : super(builder: (BuildContext context) {

    Future<int?> grantApplyDialog(String name) {
      return showDialog<int>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(Language.of(context).reply),
            content: Text(name + Language.of(context).applyGroup),
            actions: <Widget>[
              TextButton(child: Text("OK"), onPressed: () => Navigator.of(context).pop(1)),
              TextButton(child: Text("Reject"), onPressed: () => Navigator.of(context).pop(-1)),
              TextButton(child: Text("Skip"), onPressed: () => Navigator.of(context).pop(0))
            ],
          );
        }
      );
    }
    int _gID = (groupDoc.data()! as Map)['gid'];
    String _gName = (groupDoc.data()! as Map)['Name'];
    bool isManager = ((groupDoc.data()! as Map)['managers'] as List).indexOf(uID) >= 0;
    void doAddActivity() async {     
      FirebaseFirestore.instance.collection('ApplyQueue').where('gid', isEqualTo: _gID).where('response', isEqualTo: 'waiting').get().then((value) {
        value.docs.forEach((result) async {
              // grant or refuse the apply of e['uid']
          var e = result.data();
          int? ans = await grantApplyDialog(await golferName(e['uid'] as int)!);
          if (ans! > 0) {
            FirebaseFirestore.instance.collection('ApplyQueue').doc(result.id)
              .update({'response': 'OK'});
            addMember(_gID, e['uid'] as int);
          } else if (ans < 0)
            FirebaseFirestore.instance.collection('ApplyQueue').doc(result.id)
              .update({'response': 'No'});
        });
        Navigator.push(context, newActivityPage(true, _gID, uID));
      });
    }
    
    DateTime today = DateTime.now();
    Timestamp deadline = Timestamp.fromDate(DateTime(today.year, today.month, today.day));
    return Scaffold(
      appBar: AppBar(title: Text(Language.of(context).groupActivity + ':' + _gName), elevation: 1.0),
      body: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('ClubActivities').orderBy('teeOff').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            } else {
              return ListView(
                children: snapshot.data!.docs.map((doc) {
                  if ((doc.data()! as Map)["teeOff"] == null) {
                    return LinearProgressIndicator();
                  } else if ((doc.data()! as Map)["teeOff"].compareTo(deadline) < 0) {
                    FirebaseFirestore.instance.collection('ClubActivities').doc(doc.id).delete(); //anyone can delete outdated activity
                    return SizedBox.shrink();
                  } else if ((doc.data()! as Map)["gid"] != _gID || myActivities.indexOf(doc.id) >= 0) {
                    return SizedBox.shrink();
                  } else {
                    String cName = '';
                    return Card(
                      child: ListTile(
                        title: FutureBuilder(
                          future: courseName((doc.data()! as Map)['cid'] as int),
                            builder: (context, snapshot2) {
                              if (!snapshot2.hasData)
                                return const LinearProgressIndicator();
                              else
                                return Text(cName = snapshot2.data!.toString(), style: TextStyle(fontSize: 20));
                            }
                          ),
                        subtitle: Text(Language.of(context).teeOff + (doc.data()! as Map)['teeOff']!.toDate().toString().substring(0, 16) + '\n' + Language.of(context).max + (doc.data()! as Map)['max'].toString() + ' ' + Language.of(context).now + ((doc.data()! as Map)['golfers'] as List<dynamic>).length.toString() + " " + Language.of(context).fee + (doc.data()! as Map)['fee'].toString()),
                        leading: FutureBuilder(
                          future: coursePhoto((doc.data()! as Map)['cid'] as int),
                          builder: (context, snapshot3) {
                              if (!snapshot3.hasData)
                                return const CircularProgressIndicator();
                              else
                                return Image.network(snapshot3.data!.toString());
                            }
                          ),
                        trailing: Icon(Icons.keyboard_arrow_right),
                        onTap: () async {
                          Navigator.push(context, showActivityPage(doc, uID, _gName, isManager, _handicap)).then((value) {
                            var glist = doc.get('golfers');
                            if ((value?? 0) == 1) {
                              glist.add({
                                'uid': uID,
                                'name': _name + ((_sex == gendre.Female) ? Language.of(context).femaleNote : ''),
                                'scores': []
                              });
                              myActivities.add(doc.id);
                              storeMyActivities();
                              FirebaseFirestore.instance.collection('ClubActivities').doc(doc.id).update({
                                'golfers': glist
                              });
                              // Add to calendar
/*                              final event = Event(
                                title: _gName,
                                location: cName,
                                startDate: (doc.data()! as Map)['teeOff']!.toDate(),
                                endDate: (doc.data()! as Map)['teeOff']!.toDate().add(duration: Duration(hours: 5)),
                                timeZone: 'CST'
                              );
                              Add2Calendar.addEvent2Cal(event);*/
                            } else if (value == -1) {
                              glist.removeWhere((item) => item['uid'] == uID);
                              myActivities.remove(doc.id);
                              storeMyActivities();
                              // check if golfer is subgroups
                              bool found = false;
                              var subGroups = doc.get('subgroups') as List;
                              for (int i = 0; i < subGroups.length; i++) {
                                for (int j = 0; j < (subGroups[i] as Map).length; j++) {
                                  if ((subGroups[i] as Map)[j.toString()] == uID) {
                                    if ((subGroups[i] as Map).length == 1)
                                      subGroups.removeAt(i);
                                    else {
                                      (subGroups[i] as Map)[j.toString()] = (subGroups[i] as Map)[((subGroups[i] as Map).length - 1).toString()];
                                      (subGroups[i] as Map).remove(((subGroups[i] as Map).length - 1).toString());
                                    }
                                    found = true;
                                  }
                                }
                              }
                              FirebaseFirestore.instance.collection('ClubActivities').doc(doc.id).update(
                                  found ? {'golfers': glist, 'subgroups': subGroups} : {'golfers': glist}
                              );
                            }
                          });
                        }
                      )
                    );
                  }
                }).toList());
              }
            }
          );
        }
      ),
      floatingActionButton: !isManager ? null :
        FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () => doAddActivity()  
        )
    );
  });
}

_EditGroupPage editGroupPage(var groupDoc, int uID) {
  return _EditGroupPage(groupDoc, uID);
}

class _EditGroupPage extends MaterialPageRoute<bool> {
  _EditGroupPage(var groupDoc, int uID)
    : super(builder: (BuildContext context) {
          List<NameID> golfers = [];
          var _selectedGolfer;
          String _groupName = (groupDoc.data()! as Map)['Name'], _region = (groupDoc.data()! as Map)['region'], _remarks = (groupDoc.data()! as Map)['Remarks'];

          var blist = (groupDoc.data()! as Map)['members'] as List;

          if (golfers.isEmpty) {
            FirebaseFirestore.instance.collection('Golfers').get().then((value) {
              value.docs.forEach((result) {
                var items = result.data();
                int uid = items['uid'] as int;
                if ((blist.indexOf(uid) >= 0) && (((groupDoc.data()! as Map)['managers'] as List).indexOf(uid) < 0))
                  golfers.add(NameID(items['name'] + '(' + items['phone'] + ')', items['uid'] as int));
              });
            });
          }

          return Scaffold(
            appBar: AppBar(title: Text(Language.of(context).modify + ' ' + (groupDoc.data()! as Map)['Name']), elevation: 1.0),
            body: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
              return Column(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                  TextFormField(
                    showCursor: true,
                    initialValue: (groupDoc.data()! as Map)['Name'],
                    onChanged: (String value) => setState(() => _groupName = value.trim()),
                    //keyboardType: TextInputType.name,
                    decoration: InputDecoration(labelText: Language.of(context).groupName, icon: Icon(Icons.group), border: UnderlineInputBorder()),
                  ),
                  TextFormField(
                    showCursor: true,
                    initialValue: (groupDoc.data()! as Map)['region'],
                    onChanged: (String value) => setState(() => _region = value.trim()),
                    //keyboardType: TextInputType.name,
                    decoration: InputDecoration(labelText: Language.of(context).groupActRegion, icon: Icon(Icons.place), border: UnderlineInputBorder()),
                  ),
                  const SizedBox(height: 24.0),
                  TextFormField(
                    showCursor: true,
                    initialValue: (groupDoc.data()! as Map)['Remarks'],
                    onChanged: (String value) => setState(() => _remarks = value),
                    maxLines: 5,
                    decoration: InputDecoration(labelText: Language.of(context).groupRemarks, icon: Icon(Icons.edit_note), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12.0),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
                    ElevatedButton(
                        child: Text(Language.of(context).modify, style: TextStyle(fontSize: 18)),
                        onPressed: () {
                          if (_groupName != '' && _region != '') {
                            FirebaseFirestore.instance.collection('GolferClubs').doc(groupDoc.id).update({
                              "Name": _groupName,
                              "region": _region,
                              "Remarks": _remarks,
                            }).whenComplete(() => Navigator.of(context).pop(true));
                          }
                        }),
                    ElevatedButton(
                        child: Text(Language.of(context).addManager, style: TextStyle(fontSize: 18)),
                        onPressed: () {
                          showMaterialScrollPicker<NameID>(
                            context: context,
                            title: Language.of(context).selectManager,
                            items: golfers,
                            showDivider: false,
                            selectedItem: golfers[0],
                            onChanged: (value) => setState(() => _selectedGolfer = value),
                          ).then((value) {
                            if (_selectedGolfer != null) {
                              var mlist = (groupDoc.data()! as Map)['managers'] as List;
                              mlist.add(_selectedGolfer.toID());
                              FirebaseFirestore.instance.collection('GolferClubs').doc(groupDoc.id).update({
                                'managers': mlist
                              }).whenComplete(() => Navigator.of(context).pop(true));
                            }
                          });
                        }),
                    ElevatedButton(
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
                            if (_selectedGolfer != null) {
                              removeMemberAllActivities((groupDoc.data()! as Map)['gid'], _selectedGolfer.toID());
                              blist.remove(_selectedGolfer.toID());
                              FirebaseFirestore.instance.collection('GolferClubs').doc(groupDoc.id).update({
                                'members': blist
                              }).whenComplete(() => Navigator.of(context).pop(true));
                            }
                          });
                        }),
                    ]),
                    SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
                      Visibility(
                        visible: (((groupDoc.data()! as Map)['managers'] as List).length == 1) && 
                                 (((groupDoc.data()! as Map)['members'] as List).length == 1),
                        child: ElevatedButton(
                          child: Text(Language.of(context).deleteGroup, style: TextStyle(fontSize: 18)),
                          onPressed: () {                        
                            FirebaseFirestore.instance.collection('GolferClubs').doc(groupDoc.id).delete()
                              .whenComplete(() => Navigator.of(context).pop(true));
                          }
                        )
                      ),
                      Visibility(
                        visible: ((groupDoc.data()! as Map)['managers'] as List).length > 1,           
                        child: ElevatedButton(
                          child: Text(Language.of(context).quitManager, style: TextStyle(fontSize: 18)),
                          onPressed: () {
                            var mlist = (groupDoc.data()! as Map)['managers'] as List;
                            mlist.remove(uID);
                            FirebaseFirestore.instance.collection('GolferClubs').doc(groupDoc.id).update({
                              'managers': mlist
                            }).whenComplete(() => Navigator.of(context).pop(true));
                          }
                        )
                      ), 
                    ])                 
                ]);
              })
          );
    });
}


_NewGolfCoursePage newGolfCoursePage() {
  return _NewGolfCoursePage();
}

class _NewGolfCoursePage extends MaterialPageRoute<bool> {
  _NewGolfCoursePage()
      : super(builder: (BuildContext context) {
          String _courseName = '', _region = '', _photoURL = '';
          double _lat = 0, _lon = 0;
          var _courseZones = [];
          //         List<AutocompletePrediction>? predictions = [];
//          GooglePlace googlePlace = GooglePlace('AIzaSyD26EyAImrDoOMn3o6FgmSQjlttxjqmS7U');

          saveZone(var row) {
            print(row);
            _courseZones.add({
              'name': row['zoName'],
              'holes': [row['h1'], row['h2'], row['h3'], row['h4'], row['h5'], row['h6'], row['h7'], row['h8'], row['h9']],
            });
          }

          return Scaffold(
            appBar: AppBar(title: Text(Language.of(context).createNewCourse), elevation: 1.0),
            body: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
              return Center(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                TextFormField(
                  showCursor: true,
                  onChanged: (String value) => _courseName = value.trim(),
                  //keyboardType: TextInputType.name,
                  decoration: InputDecoration(labelText: Language.of(context).courseName, icon: Icon(Icons.golf_course), border: UnderlineInputBorder()),
                ),
                TextFormField(
                  showCursor: true,
                  onChanged: (String value) => _region = value.trim(),
                  decoration: InputDecoration(labelText: "Region:", icon: Icon(Icons.place), border: UnderlineInputBorder()),
                ),
                TextFormField(
                  showCursor: true,
                  onChanged: (String value) {
                    int i;
                    for (i = 0; value[i] != ','; i++) {}
                    _lat = double.parse(value.substring(0, i - 1));
                    _lon = double.parse(value.substring(i + 1));
                  },
                  decoration: InputDecoration(labelText: "Location:", icon: Icon(Icons.place), border: UnderlineInputBorder()),
                ),
                TextFormField(
                  showCursor: true,
                  onChanged: (String value) => _photoURL = value.trim(),
                  //keyboardType: TextInputType.name,
                  decoration: InputDecoration(labelText: "Photo URL:", icon: Icon(Icons.photo), border: UnderlineInputBorder()),
                ),
                SizedBox(height: 10),
                Flexible(
                    child: Editable(
                  borderColor: Colors.black,
                  tdStyle: TextStyle(fontSize: 14),
                  trHeight: 16,
                  tdAlignment: TextAlign.center,
                  thAlignment: TextAlign.center,
                  showSaveIcon: true,
                  saveIcon: Icons.save,
                  saveIconColor: Colors.blue,
                  onRowSaved: (row) => saveZone(row),
                  showCreateButton: true,
                  createButtonLabel: Text('Add zone'),
                  createButtonIcon: Icon(Icons.add),
                  createButtonColor: Colors.blue,
                  columnRatio: 0.15,
                  columns: [
                    {"title": "Zone", 'index': 1, 'key': 'zoName'},
                    {"title": "1", 'index': 2, 'key': 'h1'},
                    {"title": "2", 'index': 3, 'key': 'h2'},
                    {"title": "3", 'index': 4, 'key': 'h3'},
                    {"title": "4", 'index': 5, 'key': 'h4'},
                    {"title": "5", 'index': 6, 'key': 'h5'},
                    {"title": "6", 'index': 7, 'key': 'h6'},
                    {"title": "7", 'index': 8, 'key': 'h7'},
                    {"title": "8", 'index': 9, 'key': 'h8'},
                    {"title": "9", 'index': 10, 'key': 'h9'}
                  ],
                  rows: [
                    {'zoName': 'Ou', 'h1': '', 'h2': '', 'h3': '', 'h4': '', 'h5': '', 'h6': '', 'h7': '', 'h8': '', 'h9': ''},
                    {'zoName': 'I', 'h1': '', 'h2': '', 'h3': '', 'h4': '', 'h5': '', 'h6': '', 'h7': '', 'h8': '', 'h9': ''},
                  ],
                )),
                const SizedBox(height: 16.0),
                ElevatedButton(
                    child: Text(Language.of(context).create, style: TextStyle(fontSize: 24)),
                    onPressed: () {
                      FirebaseFirestore.instance.collection('GolfCourses').add({
                        "cid": uuidTime(),
                        "name": _courseName,
                        "region": _region,
                        "photo": _photoURL,
                        "zones": _courseZones,
                        "location": GeoPoint(_lat, _lon),
                      });
                      Navigator.of(context).pop(true);
                    }),
              ]));
            }),
          );
        });
}

class SubGroupPage extends MaterialPageRoute<bool> {
  SubGroupPage(var activity, int uId)
      : super(builder: (BuildContext context) {
          var subGroups = activity.data()!['subgroups'] as List;
          int max = (activity.data()!['max'] + 3) >> 2;
          List<List<int>> subIntGroups = [];

          void storeAndLeave() {
            var newGroups = [];
            for (int i = 0; i < subIntGroups.length; i++) {
              Map subMap = Map();
              for (int j = 0; j < subIntGroups[i].length; j++) 
                subMap[j.toString()] = subIntGroups[i][j];
              newGroups.add(subMap);
            }
            subGroups = newGroups;
            FirebaseFirestore.instance.collection('ClubActivities').doc(activity.id).update({
              'subgroups': newGroups
            }).whenComplete(() => Navigator.of(context).pop(true));
          }

          int alreadyIn = -1;
          for (int i = 0; i < subGroups.length; i++) {
            subIntGroups.add([]);
            for (int j = 0; j < (subGroups[i] as Map).length; j++) {
              subIntGroups[i].add((subGroups[i] as Map)[j.toString()]);
              if (subIntGroups[i][j] == uId) alreadyIn = i;
            }
          }
          if (subIntGroups.length == 0 || ( subIntGroups[subIntGroups.length - 1].length > 0 && 
              subIntGroups.length < max && alreadyIn < 0))
              subIntGroups.add([]);

          return Scaffold(
              appBar: AppBar(title: Text(Language.of(context).subGroup), elevation: 1.0),
              body: ListView.builder(
                  itemCount: subIntGroups.length,
                  padding: const EdgeInsets.all(10.0),
                  itemBuilder: (BuildContext context, int i) {
                    bool isfull = subIntGroups[i].length == 4;
                    return ListTile(
                      leading: CircleAvatar(
                          child: Text(String.fromCharCodes([
                        $A + i
                      ]))),
                      title: subIntGroups[i].length == 0
                          ? Text(Language.of(context).name)
                          : FutureBuilder(
                              future: golferNames(subIntGroups[i]),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return const LinearProgressIndicator();
                                else
                                  return Text(snapshot.data!.toString(), style: TextStyle(fontWeight: FontWeight.bold));
                              }),
                      trailing: (alreadyIn == i) ? Icon(Icons.person_remove_rounded, color: Colors.red,)
                              : (!isfull && alreadyIn < 0) ? Icon(Icons.add_box_outlined, color: Colors.blue,)
                              : Icon(Icons.stop, color: Colors.grey),
                      onTap: () {
                        if (alreadyIn == i) {
                          subIntGroups[i].remove(uId);
                          if (subIntGroups[i].length == 0) subIntGroups.removeAt(i);
                          storeAndLeave();
                        } else if (!isfull && alreadyIn < 0) {
                          subIntGroups[i].add(uId);
                          storeAndLeave();
                        }
                      },
                    );
                  }));
        });
}


