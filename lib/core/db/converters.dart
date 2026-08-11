import 'package:drift/drift.dart';

import '../models/margin_spec.dart';

/// Persists a [MarginSpec] as a JSON string column.
class MarginSpecConverter extends TypeConverter<MarginSpec, String> {
  const MarginSpecConverter();

  @override
  MarginSpec fromSql(String fromDb) =>
      fromDb.isEmpty ? MarginSpec.none : MarginSpec.fromJson(fromDb);

  @override
  String toSql(MarginSpec value) => value.toJson();
}
