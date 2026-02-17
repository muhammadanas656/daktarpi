class MedicalRecord {
  final int id;
  final String userId;
  final String recordFor;
  final String recordType;
  final DateTime recordDate;
  final List<String> fileUrls;
  final DateTime createdAt;

  MedicalRecord({
    required this.id,
    required this.userId,
    required this.recordFor,
    required this.recordType,
    required this.recordDate,
    required this.fileUrls,
    required this.createdAt,
  });

  factory MedicalRecord.fromJson(Map<String, dynamic> json) {
    return MedicalRecord(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      recordFor: json['record_for'] as String,
      recordType: json['record_type'] as String,
      recordDate: DateTime.parse(json['record_date'] as String),
      fileUrls: List<String>.from(json['file_urls'] ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'record_for': recordFor,
      'record_type': recordType,
      'record_date': recordDate.toIso8601String(),
      'file_urls': fileUrls,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
