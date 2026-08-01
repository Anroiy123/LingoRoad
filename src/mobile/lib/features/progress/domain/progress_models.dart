import 'package:lingoroad_mobile/core/network/api_exception.dart';

class SkillCatalogItem {
  const SkillCatalogItem(
      {required this.id,
      required this.code,
      required this.name,
      required this.nameVi,
      required this.category,
      required this.parentId});
  final int id;
  final String code, name, nameVi, category;
  final int? parentId;
  factory SkillCatalogItem.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! int ||
        value['code'] is! String ||
        value['name'] is! String ||
        value['nameVi'] is! String ||
        value['category'] is! String ||
        (value['parentId'] != null && value['parentId'] is! int)) {
      throw _malformed();
    }
    return SkillCatalogItem(
        id: value['id'] as int,
        code: value['code'] as String,
        name: value['name'] as String,
        nameVi: value['nameVi'] as String,
        category: value['category'] as String,
        parentId: value['parentId'] as int?);
  }
}

class MasteryRow {
  const MasteryRow(this.code, this.value);
  final String code;
  final double value;
  factory MasteryRow.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['skillCode'] is! String ||
        value['pCorrect'] is! num) {
      throw _malformed();
    }
    return MasteryRow(
        value['skillCode'] as String, (value['pCorrect'] as num).toDouble());
  }
}

class CategoryProgress {
  const CategoryProgress(this.category, this.percent, this.practiced);
  final String category;
  final int percent;
  final bool practiced;
}

ApiException _malformed() => const ApiException(
    code: 'malformed_response', message: 'Phản hồi tiến độ không hợp lệ');
