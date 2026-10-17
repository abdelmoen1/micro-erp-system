-- Read-only verification snapshot of the current database (docs/deploy/mysql-migration.md).
-- Run the same script on the source and on the restored target, then diff the two outputs:
--   mysql --batch --skip-column-names <db> < verification-snapshot.sql > snapshot-<source|target>.txt
-- Prints table names, exact row counts, checksums, the migrations list and column definitions.
-- It never selects row contents, and it writes nothing.

SET SESSION group_concat_max_len = 1048576;

-- 1. Exact row count per table.
SELECT GROUP_CONCAT(
         CONCAT('SELECT ''', table_name, ''' AS table_name, COUNT(*) AS row_count FROM `', table_name, '`')
         ORDER BY table_name SEPARATOR ' UNION ALL ')
  INTO @row_counts
  FROM information_schema.tables
 WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE';
PREPARE stmt FROM @row_counts;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 2. Content checksum per table (comparable when source and target run the same MySQL version).
SELECT CONCAT('CHECKSUM TABLE ',
              GROUP_CONCAT(CONCAT('`', table_name, '`') ORDER BY table_name SEPARATOR ', '),
              ' EXTENDED')
  INTO @checksums
  FROM information_schema.tables
 WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE';
PREPARE stmt FROM @checksums;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 3. Applied Laravel migrations.
SELECT migration, batch FROM migrations ORDER BY id;

-- 4. Schema: every column definition.
SELECT table_name, column_name, column_type, is_nullable, column_default, collation_name, extra
  FROM information_schema.columns
 WHERE table_schema = DATABASE()
 ORDER BY table_name, ordinal_position;

-- 5. Indexes and foreign keys.
SELECT table_name, index_name, non_unique, seq_in_index, column_name
  FROM information_schema.statistics
 WHERE table_schema = DATABASE()
 ORDER BY table_name, index_name, seq_in_index;
SELECT table_name, constraint_name, column_name, referenced_table_name, referenced_column_name
  FROM information_schema.key_column_usage
 WHERE table_schema = DATABASE() AND referenced_table_name IS NOT NULL
 ORDER BY table_name, constraint_name, ordinal_position;
