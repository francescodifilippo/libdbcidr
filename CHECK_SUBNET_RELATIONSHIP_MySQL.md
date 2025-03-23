# CHECK_SUBNET_RELATIONSHIP Function (MySQL)

This function analyzes relationships between multiple IP subnets and determines whether they meet specific criteria.

## Documentation Languages

- [English](./CHECK_SUBNET_RELATIONSHIP_MySQL.en.md)
- [Italiano](./CHECK_SUBNET_RELATIONSHIP_MySQL.it.md)
- [Latina](./CHECK_SUBNET_RELATIONSHIP_MySQL.la.md)
- [Esperanto](./CHECK_SUBNET_RELATIONSHIP_MySQL.eo.md)

## Installation

To install this function in your MySQL database, execute the following SQL commands in order:

1. First, install the helper functions if you haven't already:
[`HELPER_FUNCTIONS_MySQL.sql`](./sql/HELPER_FUNCTIONS_MySQL.sql)

3. Then install the FIND_SUBNETS_AGGREGATE function (required for some relationship checks):
[`FIND_SUBNETS_AGGREGATE_MySQL.sql`](./sql/FIND_SUBNETS_AGGREGATE_MySQL.sql)

3. Finally, install the CHECK_SUBNET_RELATIONSHIP function:
[`CHECK_SUBNET_RELATIONSHIP_MySQL.sql`](./sql/CHECK_SUBNET_RELATIONSHIP_MySQL.sql)

## Usage

### Syntax

```sql
SELECT CHECK_SUBNET_RELATIONSHIP(subnet_list, relationship_type);
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

Returns a BOOLEAN (1 or 0) indicating whether the specified relationship holds for the given subnets.

## Examples

1. Check if subnets are adjacent and form a chain:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'ADJACENT_CHAIN');
-- Returns 1 (TRUE)
```

2. Check if subnets can be perfectly aggregated:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.0.0/24,192.168.1.0/24', 'AGGREGABLE');
-- Returns 1 (TRUE) because they can be aggregated to 192.168.0.0/23
```

3. Check if subnets are all inside a container subnet:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.0.0/22', 'ALL_INSIDE');
-- Returns 1 (TRUE) because both /24 subnets are inside the /22 subnet
```

4. Check if any subnets overlap:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.1.128/25', 'ANY_OVERLAPPING');
-- Returns 1 (TRUE) because 192.168.1.0/24 overlaps with 192.168.1.128/25
```

5. Check if all subnets are valid:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'VALID');
-- Returns 1 (TRUE) because all subnets are valid
```

## Notes

- The function assumes that subnet specifications are in the correct format.
- For 'ADJACENT_CHAIN', the subnets should be provided in order.
- The 'AGGREGABLE' check works best when all subnets have the same CIDR prefix length.
- When using 'ALL_INSIDE', the containing subnet should be the last one in the list.
