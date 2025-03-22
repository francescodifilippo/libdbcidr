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

2. Then install the FIND_SUBNETS_AGGREGATE function:
```sql
CREATE FUNCTION FIND_SUBNETS_AGGREGATE(subnet_list TEXT)
RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE total_subnets INT;
    DECLARE current_subnet VARCHAR(50);
    DECLARE ip VARCHAR(15);
    DECLARE cidr INT;
    DECLARE min_ip BIGINT;
    DECLARE max_ip BIGINT;
    DECLARE current_ip BIGINT;
    DECLARE common_bits INT DEFAULT 32;
    DECLARE aggregate_cidr INT;
    DECLARE aggregate_ip BIGINT;
    
    -- Split the subnet list by comma and count subnets
    SET total_subnets = (LENGTH(subnet_list) - LENGTH(REPLACE(subnet_list, ',', ''))) + 1;
    
    -- Initialize min and max IP
    SET current_subnet = SUBSTRING_INDEX(subnet_list, ',', 1);
    SET ip = SUBSTRING_INDEX(current_subnet, '/', 1);
    SET cidr = CAST(SUBSTRING_INDEX(current_subnet, '/', -1) AS UNSIGNED);
    SET min_ip = INET_ATON(GET_NETWORK_ADDRESS(ip, cidr));
    SET max_ip = INET_ATON(GET_BROADCAST_ADDRESS(ip, cidr));
    
    -- Process each subnet to find min and max IPs
    WHILE i < total_subnets DO
        SET i = i + 1;
        SET current_subnet = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
        SET ip = SUBSTRING_INDEX(current_subnet, '/', 1);
        SET cidr = CAST(SUBSTRING_INDEX(current_subnet, '/', -1) AS UNSIGNED);
        SET current_ip = INET_ATON(GET_NETWORK_ADDRESS(ip, cidr));
        
        IF current_ip < min_ip THEN
            SET min_ip = current_ip;
        END IF;
        
        SET current_ip = INET_ATON(GET_BROADCAST_ADDRESS(ip, cidr));
        
        IF current_ip > max_ip THEN
            SET max_ip = current_ip;
        END IF;
    END WHILE;
    
    -- Find common bits from left to right
    SET common_bits = 0;
    WHILE common_bits < 32 DO
        IF ((min_ip >> (31 - common_bits)) & 1) = ((max_ip >> (31 - common_bits)) & 1) THEN
            SET common_bits = common_bits + 1;
        ELSE
            BREAK;
        END IF;
    END WHILE;
    
    -- Calculate the aggregate CIDR
    SET aggregate_cidr = common_bits;
    
    -- Calculate the aggregate network address
    SET aggregate_ip = min_ip & (POWER(2, 32) - POWER(2, 32 - aggregate_cidr));
    
    -- Return the result
    RETURN CONCAT(INET_NTOA(aggregate_ip), '/', aggregate_cidr);
END;
```

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
