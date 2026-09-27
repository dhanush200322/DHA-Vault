class CategoryModel {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final bool isSystem;
  final int documentCount;

  CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.isSystem = false,
    this.documentCount = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isSystem: json['isSystem'] as bool? ?? false,
      documentCount: (json['_count']?['documents'] as num?)?.toInt() ??
          (json['count'] as num?)?.toInt() ??
          0,
    );
  }
}
