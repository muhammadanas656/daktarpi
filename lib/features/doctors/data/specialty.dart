/// Specialty model representing a medical specialty from the `specialties` table.
class Specialty {
  final int id;
  final String name;
  final String? iconUrl;

  Specialty({
    required this.id,
    required this.name,
    this.iconUrl,
  });

  factory Specialty.fromJson(Map<String, dynamic> json) {
    return Specialty(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Specialist',
      iconUrl: json['icon_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon_url': iconUrl,
    };
  }
}
