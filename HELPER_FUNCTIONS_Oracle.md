# Helper Functions for IP Subnet Management (Oracle)

This document describes the essential helper functions required for IP subnet operations in Oracle Database. These functions provide the fundamental building blocks for the more complex subnet management operations and compensate for Oracle's lack of built-in IP address manipulation functions.

## Documentation Languages

- [English](./HELPER_FUNCTIONS_Oracle.en.md)
- [Italiano](./HELPER_FUNCTIONS_Oracle.it.md)
- [Latina](./HELPER_FUNCTIONS_Oracle.la.md)
- [Esperanto](./HELPER_FUNCTIONS_Oracle.eo.md)

## Installation

To install these helper functions in your Oracle database, execute the following SQL commands:

[`HELPER_FUNCTIONS_Oracle.sql`](./sql/HELPER_FUNCTIONS_Oracle.sql)


## Function Descriptions

### IP_TO_NUM

This function converts an IPv4 address in dotted decimal notation to its numeric representation.

#### Syntax

```sql
IP_TO_NUM(ip_address)
```

#### Parameters

- **ip_address**: A string representing an IPv4 address (e.g., '192.168.1.1')

#### Return Value

Returns a NUMBER representing the numeric value of the IP address.

#### How It Works

The function:
1. Uses Oracle's `REGEXP_SUBSTR` to extract each octet from the dotted decimal notation
2. Converts each octet to a number using `TO_NUMBER`
3. Calculates the final numeric representation by multiplying each octet by the appropriate power of 256
4. Returns the sum, which is the numeric representation of the IPv4 address

### NUM_TO_IP

This function converts a numeric representation of an IPv4 address back to dotted decimal notation.

#### Syntax

```sql
NUM_TO_IP(ip_num)
```

#### Parameters

- **ip_num**: A NUMBER representing the numeric value of an IPv4 address

#### Return Value

Returns a string containing the IP address in dotted decimal notation.

#### How It Works

The function:
1. Extracts each octet by performing division and modulo operations on the input number
2. Uses `TRUNC` to ensure integer results
3. Concatenates the octets with periods to form the dotted decimal representation

### GET_NETWORK_ADDRESS

This function calculates the network address for a given IP address and CIDR prefix length.

#### Syntax

```sql
GET_NETWORK_ADDRESS(ip, cidr)
```

#### Parameters

- **ip**: A string representing an IPv4 address (e.g., '192.168.1.1')
- **cidr**: A number representing the CIDR prefix length (0-32)

#### Return Value

Returns a string containing the network address in dotted decimal notation.

#### How It Works

The function:
1. Converts the IP address to a numeric value using `IP_TO_NUM`
2. Calculates the subnet mask from the CIDR prefix length
3. Applies a bitwise AND operation using Oracle's `BITAND` function between the IP and the mask to get the network address
4. Converts the result back to dotted decimal notation using `NUM_TO_IP`

### GET_BROADCAST_ADDRESS

This function calculates the broadcast address for a given IP address and CIDR prefix length.

#### Syntax

```sql
GET_BROADCAST_ADDRESS(ip, cidr)
```

#### Parameters

- **ip**: A string representing an IPv4 address (e.g., '192.168.1.1')
- **cidr**: A number representing the CIDR prefix length (0-32)

#### Return Value

Returns a string containing the broadcast address in dotted decimal notation.

#### How It Works

The function:
1. Converts the IP address to a numeric value using `IP_TO_NUM`
2. Calculates the subnet mask from the CIDR prefix length
3. Adds the number of hosts in the subnet (2^(32-cidr) - 1) to the network address to get the broadcast address
4. Converts the result back to dotted decimal notation using `NUM_TO_IP`

## Examples

### Converting Between IP Formats

```sql
-- Convert an IP address to a number
SELECT IP_TO_NUM('192.168.1.1') AS ip_num FROM DUAL;
-- Returns 3232235777

-- Convert a number back to an IP address
SELECT NUM_TO_IP(3232235777) AS ip_address FROM DUAL;
-- Returns '192.168.1.1'
```

### Finding Network and Broadcast Addresses

```sql
-- Find the network address for a subnet
SELECT GET_NETWORK_ADDRESS('192.168.1.15', 24) AS network_address FROM DUAL;
-- Returns '192.168.1.0'

-- Find the broadcast address for a subnet
SELECT GET_BROADCAST_ADDRESS('192.168.1.15', 24) AS broadcast_address FROM DUAL;
-- Returns '192.168.1.255'

-- Find both for a different subnet
SELECT 
    GET_NETWORK_ADDRESS('10.45.67.89', 16) AS network_address,
    GET_BROADCAST_ADDRESS('10.45.67.89', 16) AS broadcast_address
FROM DUAL;
-- Returns:
-- network_address: '10.45.0.0'
-- broadcast_address: '10.45.255.255'
```

### Using Functions in Queries

```sql
-- Check if an IP is in a specific subnet
WITH test_data AS (
    SELECT '10.20.30.40' AS ip FROM DUAL
)
SELECT 
    ip,
    '10.20.0.0/16' AS subnet,
    CASE 
        WHEN IP_TO_NUM(ip) BETWEEN 
            IP_TO_NUM(GET_NETWORK_ADDRESS('10.20.0.0', 16)) AND 
            IP_TO_NUM(GET_BROADCAST_ADDRESS('10.20.0.0', 16))
        THEN 'YES'
        ELSE 'NO'
    END AS is_in_subnet
FROM test_data;
-- Returns 'YES' indicating the IP is in the subnet
```

## Differences from MySQL

These Oracle helper functions were created to replace MySQL's built-in IP address manipulation functions:

1. **IP_TO_NUM and NUM_TO_IP**: Replace MySQL's `INET_ATON()` and `INET_NTOA()` functions respectively.

2. **Regular Expression Usage**: Oracle uses `REGEXP_SUBSTR` to parse IP octets, while MySQL can use `SUBSTRING_INDEX`.

3. **Bit Manipulation**: Oracle uses `BITAND` for bitwise AND operations, while MySQL uses the `&` operator.

4. **Function Syntax**: Oracle requires a forward slash (/) after the function definition to signal the end of the function body.

## Notes

- These helper functions are required prerequisites for the other subnet management functions in Oracle.
- The current implementation supports IPv4 addresses only.
- Oracle treats numeric IP addresses as regular numbers, so calculations involving very large subnets may need special attention to ensure numeric precision.
- In Oracle, the `IP_TO_NUM` function returns a NUMBER data type, which has sufficient precision to handle the full range of IPv4 addresses (0 to 4,294,967,295).
