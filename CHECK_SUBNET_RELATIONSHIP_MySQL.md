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

2. Then install the FIND_SUBNETS_AGGREGATE function (required for some relationship checks):
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

3. Finally, install the CHECK_SUBNET_RELATIONSHIP function:
```sql
CREATE FUNCTION CHECK_SUBNET_RELATIONSHIP(
    subnet_list TEXT,
    relationship_type VARCHAR(20)
) RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE i, j INT;
    DECLARE total_subnets INT;
    DECLARE subnet1, subnet2 VARCHAR(50);
    DECLARE ip1, ip2 VARCHAR(15);
    DECLARE cidr1, cidr2 INT;
    DECLARE all_match BOOLEAN DEFAULT TRUE;
    DECLARE any_match BOOLEAN DEFAULT FALSE;
    
    -- Count total subnets
    SET total_subnets = (LENGTH(subnet_list) - LENGTH(REPLACE(subnet_list, ',', ''))) + 1;
    
    -- If fewer than 2 subnets, certain relationships don't apply
    IF total_subnets < 2 AND relationship_type NOT IN ('VALID') THEN
        RETURN FALSE;
    END IF;
    
    -- Check relationships that apply to all subnet pairs
    CASE relationship_type
        -- Are all subnets adjacent and can form a continuous block?
        WHEN 'ADJACENT_CHAIN' THEN
            -- Sort subnets by IP (this would require a more complex implementation)
            -- For simplicity, assuming input is pre-sorted
            SET i = 1;
            WHILE i < total_subnets DO
                SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                
                SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i+1), ',', -1);
                SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
                SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                
                -- Check if the current pair is adjacent
                IF NOT (INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) + 1 = 
                        INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2))) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Are all subnets perfectly aggregable as a whole?
        WHEN 'AGGREGABLE' THEN
            -- First, check if all subnets have the same CIDR
            SET subnet1 = SUBSTRING_INDEX(subnet_list, ',', 1);
            SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
            
            SET i = 2;
            WHILE i <= total_subnets DO
                SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                
                IF cidr1 != cidr2 THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            
            -- Calculate the aggregate
            DECLARE aggregate VARCHAR(50);
            SET aggregate = FIND_SUBNETS_AGGREGATE(subnet_list);
            
            -- Check if the aggregate CIDR is exactly 1 bit less specific
            DECLARE agg_cidr INT;
            SET agg_cidr = CAST(SUBSTRING_INDEX(aggregate, '/', -1) AS UNSIGNED);
            
            -- The aggregate should be exactly one bit less specific than the original subnets
            IF agg_cidr != cidr1 - 1 THEN
                RETURN FALSE;
            END IF;
            
            -- Check if the total number of subnets is exactly 2^1 (2)
            -- This needs to be modified for multiple bits difference
            IF total_subnets != POWER(2, cidr1 - agg_cidr) THEN
                RETURN FALSE;
            END IF;
            
            RETURN TRUE;
            
        -- Are all subnets disjoint (no overlapping)?
        WHEN 'ALL_DISJOINT' THEN
            SET i = 1;
            WHILE i < total_subnets DO
                SET j = i + 1;
                WHILE j <= total_subnets DO
                    SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                    SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                    SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                    
                    SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', j), ',', -1);
                    SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
                    SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                    
                    -- Check if the subnets overlap
                    IF NOT ((INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) < INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2))) OR 
                            (INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2)) < INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)))) THEN
                        RETURN FALSE;
                    END IF;
                    
                    SET j = j + 1;
                END WHILE;
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Are all subnets contained within a single subnet?
        WHEN 'ALL_INSIDE' THEN
            -- The last subnet in the list is assumed to be the container
            SET subnet2 = SUBSTRING_INDEX(subnet_list, ',', -1);
            SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
            SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
            
            SET i = 1;
            WHILE i < total_subnets DO
                SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                
                -- Check if subnet1 is inside subnet2
                IF NOT (INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) >= INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2)) AND 
                        INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) <= INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2))) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Are all subnets identical?
        WHEN 'ALL_IDENTICAL' THEN
            SET subnet1 = SUBSTRING_INDEX(subnet_list, ',', 1);
            SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
            SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
            
            SET i = 2;
            WHILE i <= total_subnets DO
                SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
                SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                
                -- Check if subnets are identical
                IF NOT (INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) = INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2)) AND 
                        INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) = INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2))) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        -- Are any two subnets in the list overlapping?
        WHEN 'ANY_OVERLAPPING' THEN
            SET i = 1;
            WHILE i < total_subnets DO
                SET j = i + 1;
                WHILE j <= total_subnets DO
                    SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                    SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                    SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                    
                    SET subnet2 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', j), ',', -1);
                    SET ip2 = SUBSTRING_INDEX(subnet2, '/', 1);
                    SET cidr2 = CAST(SUBSTRING_INDEX(subnet2, '/', -1) AS UNSIGNED);
                    
                    -- Check if the subnets overlap
                    IF (INET_ATON(GET_BROADCAST_ADDRESS(ip1, cidr1)) >= INET_ATON(GET_NETWORK_ADDRESS(ip2, cidr2)) AND 
                        INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) <= INET_ATON(GET_BROADCAST_ADDRESS(ip2, cidr2))) THEN
                        RETURN TRUE;
                    END IF;
                    
                    SET j = j + 1;
                END WHILE;
                SET i = i + 1;
            END WHILE;
            RETURN FALSE;
            
        -- Check if all subnets are valid IPv4 subnets
        WHEN 'VALID' THEN
            SET i = 1;
            WHILE i <= total_subnets DO
                SET subnet1 = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
                SET ip1 = SUBSTRING_INDEX(subnet1, '/', 1);
                SET cidr1 = CAST(SUBSTRING_INDEX(subnet1, '/', -1) AS UNSIGNED);
                
                -- Check if subnet is valid
                IF cidr1 < 0 OR cidr1 > 32 OR INET_ATON(ip1) IS NULL THEN
                    RETURN FALSE;
                END IF;
                
                -- Check if network address matches CIDR notation
                IF INET_ATON(GET_NETWORK_ADDRESS(ip1, cidr1)) != INET_ATON(ip1) THEN
                    RETURN FALSE;
                END IF;
                
                SET i = i + 1;
            END WHILE;
            RETURN TRUE;
            
        ELSE
            RETURN FALSE;
    END CASE;
END;
```

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
