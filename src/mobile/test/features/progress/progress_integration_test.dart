import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/progress/data/progress_repository.dart';
import 'package:lingoroad_mobile/features/progress/domain/progress_models.dart';
import 'package:lingoroad_mobile/features/progress/presentation/progress_view_model.dart';

class FakeProgressRepository implements ProgressRepository {
  List<SkillCatalogItem> catalog = const [];
  List<MasteryRow> rows = const [];
  Object? error;
  int skillCalls = 0;
  int masteryCalls = 0;
  @override
  Future<List<SkillCatalogItem>> skills() async {
    skillCalls++;
    if (error != null) throw error!;
    return catalog;
  }

  @override
  Future<List<MasteryRow>> mastery() async {
    masteryCalls++;
    if (error != null) throw error!;
    return rows;
  }
}

const catalog = [
  SkillCatalogItem(
      id: 1,
      code: 'grammar',
      name: 'Grammar',
      nameVi: 'Ngữ pháp',
      category: 'grammar',
      parentId: null),
  SkillCatalogItem(
      id: 2,
      code: 'grammar.a',
      name: 'A',
      nameVi: 'A',
      category: 'grammar',
      parentId: 1),
  SkillCatalogItem(
      id: 3,
      code: 'grammar.b',
      name: 'B',
      nameVi: 'B',
      category: 'grammar',
      parentId: 1),
  SkillCatalogItem(
      id: 4,
      code: 'vocabulary.a',
      name: 'V',
      nameVi: 'V',
      category: 'vocabulary',
      parentId: null),
  SkillCatalogItem(
      id: 5,
      code: 'future.a',
      name: 'F',
      nameVi: 'F',
      category: 'future',
      parentId: null),
];

void main() {
  test('catalog model rejects malformed content', () {
    expect(() => SkillCatalogItem.fromJson({'id': 1}),
        throwsA(isA<ApiException>()));
    expect(
        MasteryRow.fromJson({'skillCode': 'grammar.a', 'pCorrect': .5}).value,
        .5);
  });

  test(
      'aggregation filters containers, handles sparse/orphan mastery and preserves order',
      () {
    final result = ProgressViewModel.aggregate(catalog, const [
      MasteryRow('grammar.a', .8),
      MasteryRow('orphan', 1),
    ]);
    expect(result.map((e) => e.category), ['grammar', 'vocabulary', 'future']);
    expect(result[0].percent, 80); // unpracticed leaves do not dilute mastery
    expect(result[0].practiced, isTrue);
    expect(result[1].percent, 0);
    expect(result[1].practiced, isFalse);
  });

  test('view model has empty, error/retry and cached catalog refresh states',
      () async {
    final repository = FakeProgressRepository();
    final vm = ProgressViewModel(repository);
    repository.error =
        const ApiException(code: 'network_unavailable', message: 'offline');
    await vm.load();
    expect(vm.state, ProgressState.error);
    repository.error = null;
    repository.catalog = catalog;
    repository.rows = const [MasteryRow('grammar.b', .9)];
    await vm.load();
    expect(vm.state, ProgressState.ready);
    expect(repository.skillCalls, 2);
    await vm.load();
    expect(repository.skillCalls, 2);
    expect(repository.masteryCalls, 3);
  });
}
