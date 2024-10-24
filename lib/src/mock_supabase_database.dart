/// A Supabase-client-like class to mutate the in-memory database within a rpc mocking.
///
/// Unlike the actual Supabase client, the `.select()`, `.insert()`, `.update()`,
/// and `.delete()` methods is chained after the filter methods, and does not
/// return a `Future`.
///
/// Example usage:
///
/// ```dart
/// // Insert a single row
/// final insertResult = db.from('users').insert({'id': 1, 'name': 'John', 'age': 30});
/// // insertResult: [{'id': 1, 'name': 'John', 'age': 30}]
///
/// // Select all rows from a table
/// final selectResult = db.from('users').select();
/// // selectResult: [{'id': 1, 'name': 'John', 'age': 30}]
///
/// // Update a row
/// final updateResult = db.from('users').eq('id', 1).update({'name': 'John Doe'});
/// // updateResult: [{'id': 1, 'name': 'John Doe', 'age': 30}]
///
/// // Delete a row
/// final deleteResult = db.from('users').eq('id', 1).delete();
/// // deleteResult: [{'id': 1, 'name': 'John Doe', 'age': 30}]
///
/// // Using filters
/// // Equal to
/// final eqResult = db.from('users').eq('age', 30).select();
/// // eqResult: [{'id': 1, 'name': 'John', 'age': 30}]
///
/// // Not equal to
/// final neqResult = db.from('users').neq('name', 'Alice').select();
/// // neqResult: [{'id': 1, 'name': 'John', 'age': 30}]
///
/// // Greater than
/// final gtResult = db.from('users').gt('age', 25).select();
/// // gtResult: [{'id': 1, 'name': 'John', 'age': 30}]
///
/// // Less than
/// final ltResult = db.from('users').lt('age', 35).select();
/// // ltResult: [{'id': 1, 'name': 'John', 'age': 30}]
///
/// // Greater than or equal to
/// final gteResult = db.from('users').gte('age', 30).select();
/// // gteResult: [{'id': 1, 'name': 'John', 'age': 30}]
///
/// // Less than or equal to
/// final lteResult = db.from('users').lte('age', 30).select();
/// // lteResult: [{'id': 1, 'name': 'John', 'age': 30}]
///
/// // Combining multiple filters
/// final combinedResult = db.from('users').eq('name', 'John').gte('age', 30).select();
/// // combinedResult: [{'id': 1, 'name': 'John', 'age': 30}]
/// ```
class MockSupabaseDatabase {
  final Map<String, List<Map<String, dynamic>>> _database;

  MockSupabaseDatabase(this._database);

  /// Creates a query builder for the specified table
  MockSupabaseQueryBuilder from(String table) {
    return MockSupabaseQueryBuilder(_database, table);
  }
}

/// A query builder that provides Supabase-like methods for querying and
/// manipulating data
class MockSupabaseQueryBuilder {
  final Map<String, List<Map<String, dynamic>>> _database;
  final String _table;
  final Map<String, String> _filters = {};
  int? _limitValue;
  int? _offsetValue;
  // Replace single order column and ascending flag with a list of order conditions
  final List<({String column, bool ascending})> _orderClauses = [];

  MockSupabaseQueryBuilder(this._database, this._table);

  /// Filters rows where [column] equals [value]
  MockSupabaseQueryBuilder eq(String column, dynamic value) {
    _filters[column] = 'eq.$value';
    return this;
  }

  /// Filters rows where [column] does not equal [value]
  MockSupabaseQueryBuilder neq(String column, dynamic value) {
    _filters[column] = 'neq.$value';
    return this;
  }

  /// Filters rows where [column] is greater than [value]
  MockSupabaseQueryBuilder gt(String column, dynamic value) {
    _filters[column] = 'gt.$value';
    return this;
  }

  /// Filters rows where [column] is less than [value]
  MockSupabaseQueryBuilder lt(String column, dynamic value) {
    _filters[column] = 'lt.$value';
    return this;
  }

  /// Filters rows where [column] is greater than or equal to [value]
  MockSupabaseQueryBuilder gte(String column, dynamic value) {
    _filters[column] = 'gte.$value';
    return this;
  }

  /// Filters rows where [column] is less than or equal to [value]
  MockSupabaseQueryBuilder lte(String column, dynamic value) {
    _filters[column] = 'lte.$value';
    return this;
  }

  /// Limits the number of rows returned
  MockSupabaseQueryBuilder limit(int limit) {
    _limitValue = limit;
    return this;
  }

  /// Sets the number of rows to skip
  MockSupabaseQueryBuilder offset(int offset) {
    _offsetValue = offset;
    return this;
  }

  /// Orders the results by [column] in ascending or descending order
  /// Can be called multiple times to sort by multiple columns
  MockSupabaseQueryBuilder order(String column, {bool ascending = false}) {
    _orderClauses.add((column: column, ascending: ascending));
    return this;
  }

  /// Inserts a new row or rows into the table
  List<Map<String, dynamic>> insert(dynamic data) {
    if (!_database.containsKey(_table)) {
      _database[_table] = [];
    }

    final List<Map<String, dynamic>> items = data is List
        ? List<Map<String, dynamic>>.from(data)
        : [Map<String, dynamic>.from(data)];

    _database[_table]!.addAll(items);
    return items;
  }

  /// Updates rows that match the query filters
  List<Map<String, dynamic>> update(Map<String, dynamic> data) {
    if (!_database.containsKey(_table)) return [];

    final updatedRows = <Map<String, dynamic>>[];
    for (var row in _database[_table]!) {
      if (_matchesFilters(row)) {
        final updatedRow = Map<String, dynamic>.from(row);
        updatedRow.addAll(data);
        updatedRows.add(updatedRow);
        _database[_table]![_database[_table]!.indexOf(row)] = updatedRow;
      }
    }
    return updatedRows;
  }

  /// Deletes rows that match the query filters
  List<Map<String, dynamic>> delete() {
    if (!_database.containsKey(_table)) return [];

    final deletedRows = <Map<String, dynamic>>[];
    _database[_table]!.removeWhere((row) {
      if (_matchesFilters(row)) {
        deletedRows.add(row);
        return true;
      }
      return false;
    });

    return deletedRows;
  }

  /// Selects rows that match the query filters
  List<Map<String, dynamic>> select() {
    if (!_database.containsKey(_table)) return [];

    var result =
        _database[_table]!.where((row) => _matchesFilters(row)).toList();

    if (_orderClauses.isNotEmpty) {
      result.sort((a, b) {
        for (final orderClause in _orderClauses) {
          final comparison = orderClause.ascending
              ? a[orderClause.column].compareTo(b[orderClause.column])
              : b[orderClause.column].compareTo(a[orderClause.column]);
          if (comparison != 0) return comparison;
        }
        return 0;
      });
    }

    if (_offsetValue != null) {
      result = result.skip(_offsetValue!).toList();
    }

    if (_limitValue != null) {
      result = result.take(_limitValue!).toList();
    }

    return result;
  }

  bool _matchesFilters(Map<String, dynamic> row) {
    for (var entry in _filters.entries) {
      final value = entry.value;
      if (value.startsWith('eq.')) {
        if (row[entry.key].toString() != value.substring(3)) return false;
      } else if (value.startsWith('neq.')) {
        if (row[entry.key].toString() == value.substring(4)) return false;
      } else if (value.startsWith('gt.')) {
        if (row[entry.key] <= num.parse(value.substring(3))) return false;
      } else if (value.startsWith('lt.')) {
        if (row[entry.key] >= num.parse(value.substring(3))) return false;
      } else if (value.startsWith('gte.')) {
        if (row[entry.key] < num.parse(value.substring(4))) return false;
      } else if (value.startsWith('lte.')) {
        if (row[entry.key] > num.parse(value.substring(4))) return false;
      }
    }
    return true;
  }
}
