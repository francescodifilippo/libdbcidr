# FIND_SUBNETS_AGGREGATE Function (MySQL)

This function calculates the minimum aggregate subnet that encompasses all the provided IP subnets.

## Documentation Languages

- [English](./FIND_SUBNETS_AGGREGATE_MySQL.en.md)
- [Italiano](./FIND_SUBNETS_AGGREGATE_MySQL.it.md)
- [Latina](./FIND_SUBNETS_AGGREGATE_MySQL.la.md)
- [Esperanto](./FIND_SUBNETS_AGGREGATE_MySQL.eo.md)

## Installation

To install this function in your MySQL database, execute the following SQL commands in order:

1. First, install the helper functions if you haven't already:
[`HELPER_FUNCTIONS_MySQL.sql`](./sql/HELPER_FUNCTIONS_MySQL.sql)

2. Then install the FIND_SUBNETS_AGGREGATE function:
[`FIND_SUBNETS_AGGREGATE_MySQL.sql`](./sql/FIND_SUBNETS_AGGREGATE_MySQL.sql)

## Usage

### Syntax

```sql
SELECT FIND_SUBNETS_AGGREGATE(subnet_list);
```

### Parameters

- **subnet_list**: A comma-separated list of subnet specifications in CIDR notation (e.g., '192.168.1.0/24,192.168.2.0/24')

### Return Value

Returns a string representing the minimum aggregate subnet (in CIDR notation) that encompasses all the provided subnets.

## Examples

1. Find the aggregate of two adjacent /24 subnets:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,192.168.1.0/24');
-- Returns '192.168.0.0/23'
```

2. Find the aggregate of non-adjacent subnets:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24,192.168.3.0/24');
-- Returns '192.168.0.0/22'
```

3. Find the aggregate of subnets with different CIDR lengths:
```sql
SELECT FIND_SUBNETS_AGGREGATE('10.0.0.0/24,10.0.1.0/24,10.0.2.0/23');
-- Returns '10.0.0.0/22'
```

4. Find the aggregate of subnets from different address spaces:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,10.0.0.0/24');
-- Returns '0.0.0.0/0' (the entire IPv4 address space)
```

5. Find the aggregate of a single subnet (returns the same subnet):
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24');
-- Returns '192.168.1.0/24'
```

## How It Works

The function operates in several steps:

1. **Parse the subnet list**: Splits the comma-separated list and counts the number of subnets.

2. **Find the minimum and maximum IP addresses**: 
   - Converts each subnet to its network address and broadcast address
   - Keeps track of the lowest network address and the highest broadcast address

3. **Calculate the common prefix**:
   - Starting from the leftmost bit, counts how many bits are identical between the minimum and maximum IP addresses
   - This count becomes the CIDR prefix length for the aggregate subnet

4. **Compute the network address**:
   - Applies the mask derived from the prefix length to the minimum IP address
   - This ensures the network address is properly aligned to the CIDR boundary

5. **Generate the CIDR notation**:
   - Combines the network address with the prefix length to create the aggregate subnet specification

## Notes

- The function always returns the smallest possible aggregate that contains all the input subnets.
- When subnets are far apart, the aggregate may include a significant number of unwanted IP addresses.
- For subnets from different major blocks (e.g., 10.x.x.x and 192.168.x.x), the aggregate will be very large.
- To identify unwanted subnets included in the aggregate, use the `LIST_UNWANTED_SUBNETS` procedure.
