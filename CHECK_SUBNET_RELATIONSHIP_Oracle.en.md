# CHECK_SUBNET_RELATIONSHIP Function (Oracle)

This function analyzes relationships between multiple IP subnets and determines whether they meet specific criteria. The Oracle implementation returns a numeric value (1 for true, 0 for false) instead of a boolean since Oracle PL/SQL doesn't have a native boolean return type for functions.

## Documentation Languages

- [English](./CHECK_SUBNET_RELATIONSHIP_Oracle.en.md)
- [Italiano](./CHECK_SUBNET_RELATIONSHIP_Oracle.it.md)
- [Latina](./CHECK_SUBNET_RELATIONSHIP_Oracle.la.md)
- [Esperanto](./CHECK_SUBNET_RELATIONSHIP_Oracle.eo.md)

## Installation

To install this function in your Oracle database, execute the following SQL commands in order:

1. First, install the helper functions if you haven't already:
[`HELPER_FUNCTIONS_Oracle.sql`](./sql/HELPER_FUNCTIONS_Oracle.sql)

2. Then install the FIND_SUBNETS_AGGREGATE function (required for some relationship checks):
[`FIND_SUBNETS_AGGREGATE_Oracle.sql`](./sql/FIND_SUBNETS_AGGREGATE_Oracle.sql)

3. Finally, install the CHECK_SUBNET_RELATIONSHIP function:
[`CHECK_SUBNET_RELATIONSHIP_Oracle.sql`](./sql/CHECK_SUBNET_RELATIONSHIP_Oracle.sql)

## Usage

### Syntax

```sql
SELECT CHECK_SUBNET_RELATIONSHIP(subnet_list, relationship_type) FROM DUAL;
```

### Parameters

- **subnet_list**: A comma-separated list of subnet specifications in CIDR notation (e.g., '192.168.1.0/24,192.168.2.0/24')
- **relationship_type**: The type of relationship to check. Valid values are:
  - 'ADJACENT_CHAIN': Checks if all subnets form a continuous chain
  - 'AGGREGABLE': Checks if all subnets can be perfectly aggregated
  - 'ALL_DISJOINT': Checks if all subnets are disjoint (no overlap)
  - 'ALL_INSIDE': Checks if all subnets are contained within the last subnet in the list
  - 'ALL_IDENTICAL': Checks if all subnets are identical
  - 'ANY_OVERLAPPING': Checks if any two subnets in the list overlap
  - 'VALID': Checks if all subnets are valid IPv4 subnets

### Return Value

Returns 1 (true) or 0 (false) indicating whether the specified relationship holds for the given subnets.

## Examples

1. Check if subnets are adjacent and form a chain:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'ADJACENT_CHAIN') AS result FROM DUAL;
-- Returns 1 (true)
```

2. Check if subnets can be perfectly aggregated:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.0.0/24,192.168.1.0/24', 'AGGREGABLE') AS result FROM DUAL;
-- Returns 1 (true) because they can be aggregated to 192.168.0.0/23
```

3. Check if subnets are all inside a container subnet:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.0.0/22', 'ALL_INSIDE') AS result FROM DUAL;
-- Returns 1 (true) because both /24 subnets are inside the /22 subnet
```

4. Check if any subnets overlap:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.1.128/25', 'ANY_OVERLAPPING') AS result FROM DUAL;
-- Returns 1 (true) because 192.168.1.0/24 overlaps with 192.168.1.128/25
```

5. Check if all subnets are valid:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'VALID') AS result FROM DUAL;
-- Returns 1 (true) because all subnets are valid
```

## Differences from MySQL Implementation

The Oracle implementation differs from the MySQL version in several ways:

1. **Return Type**: Oracle functions can't return a boolean value directly, so this function returns 1 for true and 0 for false.

2. **String Processing**: Oracle uses `REGEXP_SUBSTR` for string parsing instead of MySQL's `SUBSTRING_INDEX`.

3. **IP Conversion**: Since Oracle doesn't have built-in functions like `INET_ATON` and `INET_NTOA`, we use custom functions `IP_TO_NUM` and `NUM_TO_IP`.

4. **Bit Manipulation**: Oracle uses `BITAND` for bitwise AND operations, and different logic for bit shifting since it doesn't have direct bit-shift operators.

5. **Control Flow**: Oracle uses `IF-ELSIF-ELSE` constructs instead of MySQL's `CASE` statements for the main relationship logic.

## Notes

- The function assumes that subnet specifications are in the correct format.
- For 'ADJACENT_CHAIN', the subnets should be provided in order.
- The 'AGGREGABLE' check works best when all subnets have the same CIDR prefix length.
- When using 'ALL_INSIDE', the containing subnet should be the last one in the list.
- Oracle PL/SQL requires that all statements have a semicolon (;) terminator, and functions end with a forward slash (/) to indicate the end of the function definition.
