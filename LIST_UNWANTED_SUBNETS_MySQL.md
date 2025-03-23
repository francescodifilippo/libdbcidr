# LIST_UNWANTED_SUBNETS Procedure (MySQL)

This procedure identifies subnets that would be included in an aggregate but are not part of the original subnet list. It helps network administrators analyze the "waste" when aggregating non-contiguous subnets.

## Documentation Languages

- [English](./LIST_UNWANTED_SUBNETS_MySQL.en.md)
- [Italiano](./LIST_UNWANTED_SUBNETS_MySQL.it.md)
- [Latina](./LIST_UNWANTED_SUBNETS_MySQL.la.md)
- [Esperanto](./LIST_UNWANTED_SUBNETS_MySQL.eo.md)

## Installation

To install this procedure in your MySQL database, execute the following SQL commands in order:

1. First, install the helper functions if you haven't already:
[`HELPER_FUNCTIONS_MySQL.sql`](./sql/HELPER_FUNCTIONS_MySQL.sql)

2. Then install the LIST_UNWANTED_SUBNETS procedure:
[`LIST_UNWANTED_SUBNETS_MySQL.sql`](./sql/LIST_UNWANTED_SUBNETS_MySQL.sql)

## Usage

### Syntax

```sql
CALL LIST_UNWANTED_SUBNETS(subnet_list, aggregate_subnet);
```

### Parameters

- **subnet_list**: A comma-separated list of subnet specifications in CIDR notation (e.g., '192.168.1.0/24,192.168.3.0/24')
- **aggregate_subnet**: The aggregate subnet specification in CIDR notation (e.g., '192.168.0.0/22')

### Return Value

Returns a result set containing one column named 'subnet' with each row representing an unwanted subnet (in CIDR notation) included in the aggregate but not part of the original subnets.

## Examples

1. Find unwanted subnets when aggregating non-adjacent /24 subnets:
```sql
CALL LIST_UNWANTED_SUBNETS('192.168.1.0/24,192.168.3.0/24', '192.168.0.0/22');
```
Result:
```
+----------------+
| subnet         |
+----------------+
| 192.168.0.0/24 |
| 192.168.2.0/24 |
+----------------+
```

2. Find unwanted subnets when aggregating subnets with different prefix lengths:
```sql
CALL LIST_UNWANTED_SUBNETS('10.0.0.0/24,10.0.3.0/24', '10.0.0.0/22');
```
Result:
```
+-------------+
| subnet      |
+-------------+
| 10.0.1.0/24 |
| 10.0.2.0/24 |
+-------------+
```

3. Verify no unwanted subnets for perfectly aggregable subnets:
```sql
CALL LIST_UNWANTED_SUBNETS('192.168.0.0/24,192.168.1.0/24', '192.168.0.0/23');
```
Result: Empty result set (no unwanted subnets)

4. Find unwanted subnets in a large aggregate:
```sql
CALL LIST_UNWANTED_SUBNETS('10.0.0.0/24,192.168.0.0/24', '0.0.0.0/0');
```
Result: Very large result set containing all /24 networks in the IPv4 space except the two specified ones.

## How It Works

The procedure operates in several steps:

1. **Parse Input**: 
   - Parses the original subnet list and the aggregate subnet
   - Identifies the smallest CIDR prefix length among the original subnets

2. **Create Data Structures**:
   - Creates a temporary table to store the network and broadcast addresses of the original subnets
   - Creates a temporary table to store the results

3. **Enumerate Subnets**:
   - Iterates through all possible subnets of the same size as the smallest original subnet that fit within the aggregate
   - For each possible subnet, checks if it matches any of the original subnets
   - If not, adds it to the list of unwanted subnets

4. **Return Results**:
   - Returns the list of unwanted subnets in sorted order

## Notes

- The procedure identifies subnets at the same prefix length as the most specific subnet in the original list
- For large aggregates, the result set can be very large
- The procedure is useful for:
  - Planning IP addressing schemes
  - Evaluating the efficiency of route aggregation
  - Identifying free IP space within an aggregate
  - Assessing the impact of subnet summarization on routing tables
