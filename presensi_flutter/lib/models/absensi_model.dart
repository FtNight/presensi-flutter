class AbsensiModel {
  final int id;
  final int userId;
  final String tanggal;
  final String? jamMasuk;
  final String? jamPulang;
  final String? status;
  final double? jarakMasuk;
  final double? jarakPulang;

  AbsensiModel({
    required this.id,
    required this.userId,
    required this.tanggal,
    this.jamMasuk,
    this.jamPulang,
    this.status,
    this.jarakMasuk,
    this.jarakPulang,
  });

  factory AbsensiModel.fromJson(Map<String, dynamic> json) {
    return AbsensiModel(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      tanggal: json['tanggal'] as String? ?? '',
      jamMasuk: json['jam_masuk'] as String?,
      jamPulang: json['jam_pulang'] as String?,
      status: json['status'] as String?,
      jarakMasuk: (json['jarak_masuk'] as num?)?.toDouble(),
      jarakPulang: (json['jarak_pulang'] as num?)?.toDouble(),
    );
  }
}
