class UserModel {
  final int id;
  final String employeeId;
  final String nama;
  final String? jabatan;
  final String role;

  UserModel({
    required this.id,
    required this.employeeId,
    required this.nama,
    this.jabatan,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      employeeId: json['employee_id'] as String? ?? '',
      nama: json['nama'] as String? ?? '',
      jabatan: json['jabatan'] as String?,
      role: json['role'] as String? ?? 'karyawan',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employee_id': employeeId,
        'nama': nama,
        'jabatan': jabatan,
        'role': role,
      };
}
