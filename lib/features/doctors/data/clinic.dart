/// Clinic model representing a medical clinic from the `clinics` table.
class Clinic {
  final int id;
  final String name;
  final String address;

  Clinic({
    required this.id,
    required this.name,
    required this.address,
  });

  factory Clinic.fromJson(Map<String, dynamic> json) {
    return Clinic(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown Clinic',
      address: json['address'] as String? ?? 'Unknown Address',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
    };
  }
}
