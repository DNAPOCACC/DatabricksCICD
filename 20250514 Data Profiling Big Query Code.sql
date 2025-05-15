DECLARE dataset_name STRING DEFAULT 'TestDataset';
DECLARE project_id STRING DEFAULT 'Test-DB';

DECLARE col_profile_sql STRING;

DECLARE results ARRAY<STRUCT<
  TableName STRING,
  ColumnName STRING,
  DataType STRING,
  RowCount INT64,
  NullCount INT64,
  DistinctCount INT64,
  MinValue STRING,
  MaxValue STRING,
  Mean FLOAT64
>> DEFAULT [];

-- Declare individual output variables
DECLARE v_TableName STRING;
DECLARE v_ColumnName STRING;
DECLARE v_DataType STRING;
DECLARE v_RowCount INT64;
DECLARE v_NullCount INT64;
DECLARE v_DistinctCount INT64;
DECLARE v_MinValue STRING;
DECLARE v_MaxValue STRING;
DECLARE v_Mean FLOAT64;

-- Loop through all columns
FOR row IN (
  SELECT table_name, column_name, data_type
  FROM lh-apis.reporting.INFORMATION_SCHEMA.COLUMNS
  WHERE table_schema = dataset_name and column_name not in ('TAT_Received','TAT_Collected') --Excluding certain columns that are available in info schema but not in the actual table
)
DO
  -- Conditionally build the SQL with or without AVG() depending on the data type
  IF row.data_type IN ('INT64', 'FLOAT64', 'NUMERIC', 'BIGNUMERIC') THEN
    SET col_profile_sql = FORMAT("""
      SELECT
        '%s' AS TableName,
        '%s' AS ColumnName,
        '%s' AS DataType,
        (SELECT COUNT(*) FROM `%s.%s.%s`) AS RowCount,
        (SELECT COUNT(*) FROM `%s.%s.%s` WHERE `%s` IS NULL) AS NullCount,
        (SELECT COUNT(DISTINCT `%s`) FROM `%s.%s.%s`) AS DistinctCount,
        CAST(MIN(CAST(%s AS STRING)) AS STRING) AS MinValue,
        CAST(MAX(CAST(%s AS STRING)) AS STRING) AS MaxValue,
        AVG(SAFE_CAST(%s AS FLOAT64)) AS Mean
      FROM `%s.%s.%s`
    """,
      row.table_name,
      row.column_name,
      row.data_type,
      project_id, dataset_name, row.table_name,
      project_id, dataset_name, row.table_name, row.column_name,
      row.column_name, project_id, dataset_name, row.table_name,
      row.column_name,
      row.column_name,
      row.column_name,
      project_id, dataset_name, row.table_name
    );
  ELSEIF row.data_type IN ('JSON') THEN
    SET col_profile_sql = FORMAT("""
      SELECT
        '%s' AS TableName,
        '%s' AS ColumnName,
        '%s' AS DataType,
        (SELECT COUNT(*) FROM `%s.%s.%s`) AS RowCount,
        (SELECT COUNT(*) FROM `%s.%s.%s` WHERE `%s` IS NULL) AS NullCount,
        (SELECT COUNT(DISTINCT JSON_EXTRACT_SCALAR(%s, '$.field_name')) FROM `%s.%s.%s`) AS DistinctCount,
        CAST(MIN(CAST(JSON_EXTRACT_SCALAR(%s, '$.field_name') AS STRING)) AS STRING) AS MinValue,
        CAST(MAX(CAST(JSON_EXTRACT_SCALAR(%s, '$.field_name') AS STRING)) AS STRING) AS MaxValue,
        NULL AS Mean
      FROM `%s.%s.%s`
    """,
      row.table_name,
      row.column_name,
      row.data_type,
      project_id, dataset_name, row.table_name,
      project_id, dataset_name, row.table_name, row.column_name,
      row.column_name, project_id, dataset_name, row.table_name,
      row.column_name,
      row.column_name,
      project_id, dataset_name, row.table_name
    );
  ELSEIF row.data_type IN ('DATE', 'DATETIME', 'TIMESTAMP') THEN
    SET col_profile_sql = FORMAT("""
      SELECT
        '%s' AS TableName,
        '%s' AS ColumnName,
        '%s' AS DataType,
        (SELECT COUNT(*) FROM `%s.%s.%s`) AS RowCount,
        (SELECT COUNT(*) FROM `%s.%s.%s` WHERE `%s` IS NULL) AS NullCount,
        (SELECT COUNT(DISTINCT `%s`) FROM `%s.%s.%s`) AS DistinctCount,
        CAST(MIN(%s) AS STRING) AS MinValue,
        CAST(MAX(%s) AS STRING) AS MaxValue,
        NULL AS Mean
      FROM `%s.%s.%s`
    """,
      row.table_name,
      row.column_name,
      row.data_type,
      project_id, dataset_name, row.table_name,
      project_id, dataset_name, row.table_name, row.column_name,
      row.column_name, project_id, dataset_name, row.table_name,
      row.column_name, -- Directly using the column name for MIN
      row.column_name, -- Directly using the column name for MAX
      project_id, dataset_name, row.table_name
    );
  ELSE
    SET col_profile_sql = FORMAT("""
      SELECT
        '%s' AS TableName,
        '%s' AS ColumnName,
        '%s' AS DataType,
        (SELECT COUNT(*) FROM `%s.%s.%s`) AS RowCount,
        (SELECT COUNT(*) FROM `%s.%s.%s` WHERE `%s` IS NULL) AS NullCount,
        (SELECT COUNT(DISTINCT `%s`) FROM `%s.%s.%s`) AS DistinctCount,
        CAST(MIN(CAST(%s AS STRING)) AS STRING) AS MinValue,
        CAST(MAX(CAST(%s AS STRING)) AS STRING) AS MaxValue,
        NULL AS Mean
      FROM `%s.%s.%s`
    """,
      row.table_name,
      row.column_name,
      row.data_type,
      project_id, dataset_name, row.table_name,
      project_id, dataset_name, row.table_name, row.column_name,
      row.column_name, project_id, dataset_name, row.table_name,
      row.column_name,
      row.column_name,
      project_id, dataset_name, row.table_name
    );
  END IF;

  SELECT col_profile_sql; --Dynamic SQL output for debugging

  EXECUTE IMMEDIATE col_profile_sql
  INTO v_TableName, v_ColumnName, v_DataType,
       v_RowCount, v_NullCount, v_DistinctCount,
       v_MinValue, v_MaxValue, v_Mean;

  SET results = ARRAY_CONCAT(
    results,
    [STRUCT(
      v_TableName, v_ColumnName, v_DataType,
      v_RowCount, v_NullCount, v_DistinctCount,
      v_MinValue, v_MaxValue, v_Mean
    )]
  );

END FOR;

-- Final output
SELECT * FROM UNNEST(results)
ORDER BY TableName, ColumnName;