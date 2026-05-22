class UnitModel {
  final String id;
  final String name;
  final String shortCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UnitModel({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UnitModel.fromJson(Map<String, dynamic> json) => UnitModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        shortCode: json['short_code'] as String? ?? '',
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()) : DateTime.now(),
      );

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'short_code': shortCode,
      };
}
