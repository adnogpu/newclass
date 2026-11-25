class RoomRef {
  const RoomRef({
    required this.roomNo,
    required this.sysid,
    required this.areaid,
    required this.districtid,
    required this.buildid,
    required this.floorid,
    required this.roomid,
    required this.roomName,
    required this.buildName,
    required this.floorName,
  });

  final String roomNo;
  final String sysid;
  final String areaid;
  final String districtid;
  final String buildid;
  final String floorid;
  final String roomid;
  final String roomName;
  final String buildName;
  final String floorName;

  String get displayName {
    final parts = <String>[
      if (buildName.trim().isNotEmpty) buildName.trim(),
      if (floorName.trim().isNotEmpty) floorName.trim(),
      if (roomName.trim().isNotEmpty) roomName.trim(),
    ];
    return parts.join(' · ');
  }

  Map<String, dynamic> toJson() => {
    'roomNo': roomNo,
    'sysid': sysid,
    'areaid': areaid,
    'districtid': districtid,
    'buildid': buildid,
    'floorid': floorid,
    'roomid': roomid,
    'roomName': roomName,
    'buildName': buildName,
    'floorName': floorName,
  };

  factory RoomRef.fromJson(Map<String, dynamic> json) => RoomRef(
    roomNo: '${json['roomNo'] ?? ''}',
    sysid: '${json['sysid'] ?? ''}',
    areaid: '${json['areaid'] ?? ''}',
    districtid: '${json['districtid'] ?? ''}',
    buildid: '${json['buildid'] ?? ''}',
    floorid: '${json['floorid'] ?? ''}',
    roomid: '${json['roomid'] ?? ''}',
    roomName: '${json['roomName'] ?? ''}',
    buildName: '${json['buildName'] ?? ''}',
    floorName: '${json['floorName'] ?? ''}',
  );
}
