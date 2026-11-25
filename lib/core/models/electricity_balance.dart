import 'room_ref.dart';

class ElectricityBalance {
  const ElectricityBalance({
    required this.degree,
    required this.fetchedAt,
    this.room,
  });

  /// Raw value returned by the endpoint, e.g. "77.52001953125".
  final String degree;
  final DateTime fetchedAt;
  final RoomRef? room;

  String get displayDegree {
    final value = double.tryParse(degree.trim());
    if (value == null) return degree.trim();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Map<String, dynamic> toJson() => {
    'degree': degree,
    'fetchedAt': fetchedAt.toIso8601String(),
    if (room != null) 'room': room!.toJson(),
  };

  factory ElectricityBalance.fromJson(Map<String, dynamic> json) {
    final roomJson = json['room'];
    return ElectricityBalance(
      degree: '${json['degree'] ?? ''}',
      fetchedAt:
          DateTime.tryParse('${json['fetchedAt'] ?? ''}') ?? DateTime.now(),
      room: roomJson is Map
          ? RoomRef.fromJson(Map<String, dynamic>.from(roomJson))
          : null,
    );
  }
}
