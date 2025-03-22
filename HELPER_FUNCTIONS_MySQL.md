# Helper Functions for IP Subnet Management (MySQL)

This document describes the essential helper functions required for IP subnet operations in MySQL. These functions provide the fundamental building blocks for the more complex subnet management operations.

## Documentation Languages

- [English](./HELPER_FUNCTIONS_MySQL.en.md)
- [Italiano](./HELPER_FUNCTIONS_MySQL.it.md)
- [Latina](./HELPER_FUNCTIONS_MySQL.la.md)
- [Esperanto](./HELPER_FUNCTIONS_MySQL.eo.md)

## Installation

To install these helper functions in your MySQL database, execute the following SQL commands:

```sql
-- Helper function to get the network address from an IP and CIDR
CREATE FUNCTION GET_NETWORK_ADDRESS(ip VARCHAR(15), cidr INT)
RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN
    DECLARE ip_num BIGINT;
    DECLARE mask BIGINT;
    
    SET ip_num = INET_ATON(ip);
    SET mask = POWER(2, 32) - POWER(2, 32 - cidr);
    
    RETURN INET_NTOA(ip_num & mask);
END;

-- Helper function to get the broadcast address from an IP and CIDR
CREATE FUNCTION GET_BROADCAST_ADDRESS(ip VARCHAR(15), cidr INT)
RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN
    DECLARE ip_num BIGINT;
    DECLARE mask BIGINT;
    DECLARE broadcast BIGINT;
    
    SET ip_num = INET_ATON(ip);
    SET mask = POWER(2, 32) - POWER(2, 32 - cidr);
    SET broadcast = ip_num | (POWER(2, 32 - cidr) - 1);
    
    RETURN INET_NTOA(broadcast);
END;
```

## Function Descriptions

### GET_NETWORK_ADDRESS

This function calculates the network address for a given IP address and CIDR prefix length.

#### Syntax

```sql
GET_NETWORK_ADDRESS(ip, cidr)
```

#### Parameters

- **ip**: A string representing an IPv4 address (e.g., '192.168.1.1')
- **cidr**: An integer representing the CIDR prefix length (0-32)

#### Return Value

Returns a string containing the network address in dotted decimal notation.

#### How It Works

The function:
1. Converts the IP address to a numeric value using MySQL's `INET_ATON()` function
2. Calculates the subnet mask from the CIDR prefix length
3. Applies a bitwise AND operation between the IP and the mask to get the network address
4. Converts the result back to dotted decimal notation using `INET_NTOA()`

### GET_BROADCAST_ADDRESS

This function calculates the broadcast address for a given IP address and CIDR prefix length.

#### Syntax

```sql
GET_BROADCAST_ADDRESS(ip, cidr)
```

#### Parameters

- **ip**: A string representing an IPv4 address (e.g., '192.168.1.1')
- **cidr**: An integer representing the CIDR prefix length (0-32)

#### Return Value

Returns a string containing the broadcast address in dotted decimal notation.

#### How It Works

The function:
1. Converts the IP address to a numeric value using MySQL's `INET_ATON()` function
2. Calculates the subnet mask from the CIDR prefix length
3. Applies a bitwise OR operation between the IP and the inverse of the mask to get the broadcast address
4. Converts the result back to dotted decimal notation using `INET_NTOA()`

## Examples

### Finding the Network Address

```sql
SELECT GET_NETWORK_ADDRESS('192.168.1.15', 24);
-- Returns '192.168.1.0'

SELECT GET_NETWORK_ADDRESS('10.45.67.89', 16);
-- Returns '10.45.0.0'

SELECT GET_NETWORK_ADDRESS('172.16.28.30', 20);
-- Returns '172.16.16.0'
```

### Finding the Broadcast Address

```sql
SELECT GET_BROADCAST_ADDRESS('192.168.1.15', 24);
-- Returns '192.168.1.255'

SELECT GET_BROADCAST_ADDRESS('10.45.67.89', 16);
-- Returns '10.45.255.255'

SELECT GET_BROADCAST_ADDRESS('172.16.28.30', 20);
-- Returns '172.16.31.255'
```

### Using Both Functions Together

```sql
-- Find both the network and broadcast address for a subnet
SELECT 
    GET_NETWORK_ADDRESS('192.168.5.37', 22) AS network_address,
    GET_BROADCAST_ADDRESS('192.168.5.37', 22) AS broadcast_address;
-- Returns:
-- network_address: '192.168.4.0'
-- broadcast_address: '192.168.7.255'

-- Check if an IP is in a specific subnet
SELECT 
    '10.20.30.40' AS ip,
    '10.20.0.0/16' AS subnet,
    (INET_ATON('10.20.30.40') BETWEEN 
     INET_ATON(GET_NETWORK_ADDRESS('10.20.0.0', 16)) AND 
     INET_ATON(GET_BROADCAST_ADDRESS('10.20.0.0', 16))) AS is_in_subnet;
-- Returns 1 (TRUE) indicating the IP is in the subnet
```

## Notes

- These functions rely on MySQL's built-in `INET_ATON()` and `INET_NTOA()` functions, which are available in MySQL 5.6.3 and later.
- The functions have the `DETERMINISTIC` attribute, which helps with query optimization.
- These helper functions are required prerequisites for the other subnet management functions:
  - `CHECK_SUBNET_RELATIONSHIP`
  - `FIND_SUBNETS_AGGREGATE`
  - `LIST_UNWANTED_SUBNETS`
- The current implementation supports IPv4 addresses only.
