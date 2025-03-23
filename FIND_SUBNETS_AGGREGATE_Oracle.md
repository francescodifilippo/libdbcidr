# FIND_SUBNETS_AGGREGATE Function (Oracle)

This function calculates the minimum aggregate subnet that encompasses all the provided IP subnets. The Oracle implementation handles the string manipulation and bit operations differently from the MySQL version due to the differences in the available built-in functions.

## Documentation Languages

- [English](./FIND_SUBNETS_AGGREGATE_Oracle.en.md)
- [Italiano](./FIND_SUBNETS_AGGREGATE_Oracle.it.md)
- [Latina](./FIND_SUBNETS_AGGREGATE_Oracle.la.md)
- [Esperanto](./FIND_SUBNETS_AGGREGATE_Oracle.eo.md)

## Installation

To install this function in your Oracle database, execute the following SQL commands in order:

1. First, install the helper functions if you haven't already:
[`HELPER_FUNCTIONS_Oracle.sql`](./sql/HELPER_FUNCTIONS_Oracle.sql)

2. Then install the FIND_SUBNETS_AGGREGATE function:
[`FIND_SUBNETS_AGGREGATE_Oracle.sql`](./sql/FIND_SUBNETS_AGGREGATE_Oracle.sql)

## Usage

### Syntax

```sql
SELECT FIND_SUBNETS_AGGREGATE(subnet_list) FROM DUAL;
```

### Parameters

- **subnet_list**: A comma-separated list of subnet specifications in CIDR notation (e.g., '192.168.1.0/24,192.168.2.0/24')

### Return Value

Returns a string representing the minimum aggregate subnet (in CIDR notation) that encompasses all the provided subnets.

## Examples

1. Find the aggregate of two adjacent /24 subnets:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,192.168.1.0/24') AS aggregate_subnet FROM DUAL;
-- Returns '192.168.0.0/23'
```

2. Find the aggregate of non-adjacent subnets:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24,192.168.3.0/24') AS aggregate_subnet FROM DUAL;
-- Returns '192.168.0.0/22'
```

3. Find the aggregate of subnets with different CIDR lengths:
```sql
SELECT FIND_SUBNETS_AGGREGATE('10.0.0.0/24,10.0.1.0/24,10.0.2.0/23') AS aggregate_subnet FROM DUAL;
-- Returns '10.0.0.0/22'
```

4. Find the aggregate of subnets from different address spaces:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,10.0.0.0/24') AS aggregate_subnet FROM DUAL;
-- Returns '0.0.0.0/0' (the entire IPv4 address space)
```

5. Find the aggregate of a single subnet (returns the same subnet):
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24') AS aggregate_subnet FROM DUAL;
-- Returns '192.168.1.0/24'
```

## How It Works

The function operates in several steps:

1. **Parse the subnet list**: Uses Oracle's REGEXP functions to split the comma-separated list and count the number of subnets.

2. **Find the minimum and maximum IP addresses**: 
   - Converts each subnet to its network address and broadcast address using the helper functions
   - Keeps track of the lowest network address and the highest broadcast address

3. **Calculate the common prefix**:
   - Starting from the leftmost bit, counts how many bits are identical between the minimum and maximum IP addresses
   - Since Oracle doesn't have direct bit-shift operators like MySQL, it uses division and BITAND operations to check each bit
   - This count becomes the CIDR prefix length for the aggregate subnet

4. **Compute the network address**:
   - Applies the mask derived from the prefix length to the minimum IP address using BITAND
   - This ensures the network address is properly aligned to the CIDR boundary

5. **Generate the CIDR notation**:
   - Combines the network address with the prefix length to create the aggregate subnet specification

## Differences from MySQL Implementation

The Oracle implementation differs from the MySQL version in several ways:

1. **String Manipulation**: Oracle uses `REGEXP_SUBSTR` for string processing instead of MySQL's `SUBSTRING_INDEX`.

2. **IP Conversion**: Oracle requires custom functions `IP_TO_NUM` and `NUM_TO_IP` since it lacks MySQL's built-in `INET_ATON()` and `INET_NTOA()` functions.

3. **Bit Operations**: Oracle doesn't support direct bit-shift operators like MySQL's `>>`. Instead, the function uses division by powers of 2 along with `FLOOR()` and `BITAND()` to simulate the bit-shift operations.

4. **Variable Declaration**: Oracle PL/SQL requires all variables to be declared at the beginning of a block, while MySQL allows more flexibility in variable declarations.

5. **Syntax Differences**: Oracle requires a forward slash (/) after function definitions and uses a different loop structure syntax.

## Notes

- The function always returns the smallest possible aggregate that contains all the input subnets.
- When subnets are far apart, the aggregate may include a significant number of unwanted IP addresses.
- For subnets from different major blocks (e.g., 10.x.x.x and 192.168.x.x), the aggregate will be very large.
- To identify unwanted subnets included in the aggregate, use the `LIST_UNWANTED_SUBNETS` procedure.
- This function is a dependency for the `CHECK_SUBNET_RELATIONSHIP` function when testing for 'AGGREGABLE' relationships.
