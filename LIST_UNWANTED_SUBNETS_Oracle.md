# LIST_UNWANTED_SUBNETS Procedure (Oracle)

This procedure identifies subnets that would be included in an aggregate but are not part of the original subnet list. It helps network administrators analyze the "waste" when aggregating non-contiguous subnets.

## Documentation Languages

- [English](./LIST_UNWANTED_SUBNETS_Oracle.en.md)
- [Italiano](./LIST_UNWANTED_SUBNETS_Oracle.it.md)
- [Latina](./LIST_UNWANTED_SUBNETS_Oracle.la.md)
- [Esperanto](./LIST_UNWANTED_SUBNETS_Oracle.eo.md)

## Installation

To install this procedure in your Oracle database, execute the following SQL commands in order:

1. First, install the helper functions if you haven't already:
[`HELPER_FUNCTIONS_Oracle.sql`](./sql/HELPER_FUNCTIONS_Oracle.sql)

2. Then install the LIST_UNWANTED_SUBNETS procedure:
[`LIST_UNWANTED_SUBNETS_Oracle.sql`](./sql/LIST_UNWANTED_SUBNETS_Oracle.sql)

## Usage

### Syntax

```sql
-- Declare a cursor variable
VARIABLE result_cursor REFCURSOR;

-- Call the procedure
EXEC LIST_UNWANTED_SUBNETS('subnet_list', 'aggregate_subnet', :result_cursor);

-- Print the results
PRINT result_cursor;
```

### Parameters

- **subnet_list**: A comma-separated list of subnet specifications in CIDR notation (e.g., '192.168.1.0/24,192.168.3.0/24')
- **aggregate_subnet**: The aggregate subnet specification in CIDR notation (e.g., '192.168.0.0/22')
- **result_cursor**: An OUT parameter that returns a cursor with the results

### Return Value

Returns a cursor pointing to a result set containing one column named 'subnet' with each row representing an unwanted subnet (in CIDR notation) included in the aggregate but not part of the original subnets.

## Examples

1. Find unwanted subnets when aggregating non-adjacent /24 subnets:
```sql
-- Declare cursor variable
VARIABLE result_cursor REFCURSOR;

-- Execute procedure
EXEC LIST_UNWANTED_SUBNETS('192.168.1.0/24,192.168.3.0/24', '192.168.0.0/22', :result_cursor);

-- Print results
PRINT result_cursor;
```
Result:
```
SUBNET
----------------
192.168.0.0/24
192.168.2.0/24
```

2. Find unwanted subnets when aggregating subnets with different prefix lengths:
```sql
-- Declare cursor variable
VARIABLE result_cursor REFCURSOR;

-- Execute procedure
EXEC LIST_UNWANTED_SUBNETS('10.0.0.0/24,10.0.3.0/24', '10.0.0.0/22', :result_cursor);

-- Print results
PRINT result_cursor;
```
Result:
```
SUBNET
-------------
10.0.1.0/24
10.0.2.0/24
```

3. Verify no unwanted subnets for perfectly aggregable subnets:
```sql
-- Declare cursor variable
VARIABLE result_cursor REFCURSOR;

-- Execute procedure
EXEC LIST_UNWANTED_SUBNETS('192.168.0.0/24,192.168.1.0/24', '192.168.0.0/23', :result_cursor);

-- Print results
PRINT result_cursor;
```
Result: Empty result set (no unwanted subnets)

## How It Works

The procedure operates in several steps:

1. **Parse Input**: 
   - Parses the original subnet list and the aggregate subnet
   - Identifies the smallest CIDR prefix length among the original subnets

2. **Create Data Structures**:
   - Creates a collection to store the network and broadcast addresses of the original subnets
   - Creates a temporary table to store the results

3. **Enumerate Subnets**:
   - Iterates through all possible subnets of the same size as the smallest original subnet that fit within the aggregate
   - For each possible subnet, checks if it matches any of the original subnets
   - If not, adds it to the list of unwanted subnets

4. **Return Results**:
   - Opens a cursor containing the list of unwanted subnets in sorted order

## Differences from MySQL Implementation

The Oracle implementation differs from the MySQL version in several ways:

1. **Result Return Method**: Oracle uses a REF CURSOR to return the result set, while MySQL directly returns a result set from the procedure.

2. **Collections vs. Temporary Tables**: Oracle uses PL/SQL collections (nested tables) to store original subnet data in memory before checking for unwanted subnets, while MySQL creates a temporary table.

3. **String Processing**: Oracle uses `REGEXP_SUBSTR` for string parsing instead of MySQL's `SUBSTRING_INDEX`.

4. **IP Conversion**: Oracle uses custom functions `IP_TO_NUM` and `NUM_TO_IP` since it lacks built-in functions like MySQL's `INET_ATON` and `INET_NTOA`.

5. **Error Handling**: The Oracle version includes exception handling for dropping the temporary table if it doesn't exist.

6. **Temporary Tables**: Oracle uses global temporary tables with the `ON COMMIT PRESERVE ROWS` option, ensuring the data remains available after the transaction.

## Notes

- The procedure identifies subnets at the same prefix length as the most specific subnet in the original list
- For large aggregates, the result set can be very large
- The procedure is useful for:
  - Planning IP addressing schemes
  - Evaluating the efficiency of route aggregation
  - Identifying free IP space within an aggregate
  - Assessing the impact of subnet summarization on routing tables
- In Oracle, to view the results, you must use the `PRINT` command after the procedure execution, or fetch from the cursor in a PL/SQL block
- The `EXECUTE IMMEDIATE` statements are used for dynamic SQL to create and manipulate the temporary table
