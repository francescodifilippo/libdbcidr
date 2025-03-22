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

2. Then install the LIST_UNWANTED_SUBNETS procedure:
```sql
CREATE PROCEDURE LIST_UNWANTED_SUBNETS(
    subnet_list TEXT,
    aggregate_subnet VARCHAR(50)
)
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE total_subnets INT;
    DECLARE current_subnet VARCHAR(50);
    DECLARE original_ip VARCHAR(15);
    DECLARE original_cidr INT;
    DECLARE aggregate_ip VARCHAR(15);
    DECLARE aggregate_cidr INT;
    DECLARE smallest_cidr INT DEFAULT 0;
    DECLARE aggregate_start BIGINT;
    DECLARE aggregate_end BIGINT;
    DECLARE subnet_size BIGINT;
    DECLARE current_subnet_start BIGINT;
    DECLARE current_subnet_end BIGINT;
    
    -- Create a temporary table for original subnets
    DROP TEMPORARY TABLE IF EXISTS original_subnets;
    CREATE TEMPORARY TABLE original_subnets (
        network_address BIGINT,
        broadcast_address BIGINT,
        cidr INT
    );
    
    -- Parse the aggregate subnet
    SET aggregate_ip = SUBSTRING_INDEX(aggregate_subnet, '/', 1);
    SET aggregate_cidr = CAST(SUBSTRING_INDEX(aggregate_subnet, '/', -1) AS UNSIGNED);
    SET aggregate_start = INET_ATON(GET_NETWORK_ADDRESS(aggregate_ip, aggregate_cidr));
    SET aggregate_end = INET_ATON(GET_BROADCAST_ADDRESS(aggregate_ip, aggregate_cidr));
    
    -- Split the subnet list by comma and count subnets
    SET total_subnets = (LENGTH(subnet_list) - LENGTH(REPLACE(subnet_list, ',', ''))) + 1;
    
    -- Process each original subnet
    WHILE i <= total_subnets DO
        SET current_subnet = SUBSTRING_INDEX(SUBSTRING_INDEX(subnet_list, ',', i), ',', -1);
        SET original_ip = SUBSTRING_INDEX(current_subnet, '/', 1);
        SET original_cidr = CAST(SUBSTRING_INDEX(current_subnet, '/', -1) AS UNSIGNED);
        
        -- Keep track of the smallest CIDR (most specific subnet)
        IF smallest_cidr = 0 OR original_cidr > smallest_cidr THEN
            SET smallest_cidr = original_cidr;
        END IF;
        
        -- Insert into original subnets table
        INSERT INTO original_subnets VALUES (
            INET_ATON(GET_NETWORK_ADDRESS(original_ip, original_cidr)),
            INET_ATON(GET_BROADCAST_ADDRESS(original_ip, original_cidr)),
            original_cidr
        );
        
        SET i = i + 1;
    END WHILE;
    
    -- Create a temporary table for results
    DROP TEMPORARY TABLE IF EXISTS unwanted_subnets;
    CREATE TEMPORARY TABLE unwanted_subnets (
        subnet VARCHAR(50)
    );
    
    -- Determine the subnet size based on the smallest CIDR
    SET subnet_size = POWER(2, 32 - smallest_cidr);
    
    -- Iterate through all possible subnets in the aggregate
    SET current_subnet_start = aggregate_start;
    
    WHILE current_subnet_start <= aggregate_end DO
        -- Calculate the end of this subnet
        SET current_subnet_end = current_subnet_start + subnet_size - 1;
        
        -- Check if this subnet is part of the original subnets
        IF NOT EXISTS (
            SELECT 1 FROM original_subnets 
            WHERE network_address = current_subnet_start AND broadcast_address = current_subnet_end
        ) THEN
            -- This is an unwanted subnet, add it to results
            INSERT INTO unwanted_subnets VALUES (
                CONCAT(INET_NTOA(current_subnet_start), '/', smallest_cidr)
            );
        END IF;
        
        -- Move to next subnet
        SET current_subnet_start = current_subnet_start + subnet_size;
    END WHILE;
    
    -- Return the results
    SELECT subnet FROM unwanted_subnets ORDER BY subnet;
END;
```

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
