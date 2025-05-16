class DataProcessor {
  // Process and mark cells that differ between consecutive records with the same Badge NO
  static List<Map<String, dynamic>> processAndMarkDifferentCells(
    List<Map<String, dynamic>> data,
    List<String> columns,
    Set<String> processedBadgeNumbers, {
    List<Map<String, dynamic>> existingData = const [],
    bool checkExisting = false,
  }) {
    if (data.isEmpty) return [];

    final badgeNoColumn = columns.firstWhere(
      (col) => col.toLowerCase().contains('badge'),
      orElse: () => '',
    );

    if (badgeNoColumn.isEmpty) {
      return data; // No Badge NO column found, return original data
    }

    // First, remove exact duplicates from the incoming data
    final uniqueData = <Map<String, dynamic>>[];
    for (final record in data) {
      bool isDuplicate = false;

      for (final uniqueRecord in uniqueData) {
        bool allFieldsMatch = true;

        // Compare all fields except metadata fields and id
        for (final column in columns) {
          if (column.endsWith('_highlighted') || column == 'id') continue;

          if (record[column]?.toString() != uniqueRecord[column]?.toString()) {
            allFieldsMatch = false;
            break;
          }
        }

        if (allFieldsMatch) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        uniqueData.add(record);
      }
    }

    // Now group by badge number for highlighting differences
    final Map<String, List<Map<String, dynamic>>> recordsByBadgeNo = {};

    // If loading more data, include existing records in the comparison
    if (checkExisting && existingData.isNotEmpty) {
      // First, group existing records by badge number
      for (final record in existingData) {
        final badgeNo = record[badgeNoColumn]?.toString() ?? '';
        if (badgeNo.isEmpty) continue;

        recordsByBadgeNo
            .putIfAbsent(badgeNo, () => [])
            .add(Map<String, dynamic>.from(record));
      }
    }

    // Group new records by Badge NO
    for (final record in uniqueData) {
      final badgeNo = record[badgeNoColumn]?.toString() ?? '';
      if (badgeNo.isEmpty) continue;

      recordsByBadgeNo
          .putIfAbsent(badgeNo, () => [])
          .add(Map<String, dynamic>.from(record));
    }

    // Process and mark different cells for each group
    final processedData = <Map<String, dynamic>>[];

    for (final entry in recordsByBadgeNo.entries) {
      final badgeNo = entry.key;
      final records = entry.value;

      // Skip if we've already processed this badge number in a previous batch
      // and there are no new records for this badge number
      if (checkExisting &&
          processedBadgeNumbers.contains(badgeNo) &&
          !records.any((r) => !existingData.contains(r))) {
        continue;
      }

      // Add to processed set to prevent future duplicates
      processedBadgeNumbers.add(badgeNo);

      // If only one record with this Badge NO, add it as is
      if (records.length == 1) {
        // Only add if it's a new record (not already in existingData)
        if (!checkExisting || !existingData.contains(records.first)) {
          processedData.add(records.first);
        }
        continue;
      }

      // Sort records by id to ensure chronological order
      records.sort(
        (a, b) => (a['id'] as int? ?? 0).compareTo(b['id'] as int? ?? 0),
      );

      // If loading more data, only add new records
      if (checkExisting) {
        final newRecords =
            records
                .where(
                  (r) =>
                      !existingData.any(
                        (existing) => existing['id'] == r['id'],
                      ),
                )
                .toList();

        if (newRecords.isEmpty) continue;

        // Compare each new record with all previous records with the same badge number
        for (final newRecord in newRecords) {
          for (final existingRecord in records.where(
            (r) =>
                r['id'] != newRecord['id'] &&
                (r['id'] as int? ?? 0) < (newRecord['id'] as int? ?? 0),
          )) {
            // Compare columns
            for (final column in columns) {
              // Skip Badge NO column and metadata columns in comparison
              if (column == badgeNoColumn ||
                  column.endsWith('_highlighted') ||
                  column == 'id')
                continue;

              if (existingRecord[column]?.toString() !=
                  newRecord[column]?.toString()) {
                // Mark this cell as different
                newRecord['${column}_highlighted'] = true;
              }
            }
          }
          processedData.add(newRecord);
        }
      } else {
        // Original logic for first page load
        processedData.add(records.first);

        // Compare each record with the previous one
        for (int i = 1; i < records.length; i++) {
          final previousRecord = records[i - 1];
          final currentRecord = records[i];

          // Compare
          for (final column in columns) {
            // Skip Badge NO column in comparison
            if (column == badgeNoColumn) continue;

            if (previousRecord[column]?.toString() !=
                currentRecord[column]?.toString()) {
              // Mark this cell as different by adding metadata
              currentRecord['${column}_highlighted'] = true;
            }
          }

          processedData.add(currentRecord);
        }
      }
    }

    return processedData;
  }
}
