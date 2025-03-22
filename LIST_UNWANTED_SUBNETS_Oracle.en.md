# LIST_UNWANTED_SUBNETS Procedure (Oracle)

This procedure identifies subnets that would be included in an aggregate but are not part of the original subnet list. It helps network administrators analyze the "waste" when aggregating non-contiguous subnets.

## Documentation Languages

- [English](./LIST_UNWANTED_SUBNETS_Oracle.en.md)
- [Italiano](./LIST_UNWANTED_SUBNETS_Oracle.it.md)
- [Latina](./LIST_UNWANTED_SUBNETS_Oracle.la.md)
- [Esperanto](./LIST_UNWANTED_SUBNETS_Oracle.eo.md)

## Installation

To install this procedure in your Oracle database, execute the following SQL commands in order:

1. First, install the helper functions if you haven't already:
```sql
-- Convert IP address to number
CREATE OR REPLACE FUNCTION IP_TO_NUM(ip_address IN VARCHAR2)
RETURN NUMBER IS
    v_octet1 NUMBER;
    v_octet2 NUMBER;
    v_octet3 NUMBER;
    v_octet4 NUMBER;
BEGIN
    v_octet1 := TO_NUMBER(REGEXP_SUBSTR(ip_address, '[^.]+', 1, 1));
    v_octet2 := TO_NUMBER(REGEXP_SUBSTR(ip_address, '[^.]+', 1, 2));
    v_octet3 := TO_NUMBER(REGEXP_SUBSTR(ip_address, '[^.]+', 1, 3));
    v_octet4 := TO_NUMBER(REGEXP_SUBSTR(ip_address, '[^.]+', 1, 4));
    
    RETURN (v_octet1 * 256 * 256 * 256) + 
           (v_octet2 * 256 * 256) + 
           (v_octet3 * 256) + 
           v_octet4;
END;
/

-- Convert number to IP address
CREATE OR REPLACE FUNCTION NUM_TO_IP(ip_num IN NUMBER)
RETURN VARCHAR2 IS
    v_octet1 NUMBER;
    v_octet2 NUMBER;
    v_octet3 NUMBER;
    v_octet4 NUMBER;
BEGIN
    v_octet1 := TRUNC(ip_num / (256 * 256 * 256));
    v_octet2 := TRUNC(MOD(ip_num, 256 * 256 * 256) / (256 * 256));
    v_octet3 := TRUNC(MOD(ip_num, 256 * 256) / 256);
    v_octet4 := MOD(ip_num, 256);
    
    RETURN v_octet1 || '.' || v_octet2 || '.' || v_octet3 || '.' || v_octet4;
END;
/

-- Helper function to get the network address from an IP and CIDR
CREATE OR REPLACE FUNCTION GET_NETWORK_ADDRESS(ip IN VARCHAR2, cidr IN NUMBER)
RETURN VARCHAR2 IS
    ip_num NUMBER;
    mask NUMBER;
BEGIN
    ip_num := IP_TO_NUM(ip);
    mask := POWER(2, 32) - POWER(2, 32 - cidr);
    
    RETURN NUM_TO_IP(BITAND(ip_num, mask));
END;
/

-- Helper function to get the broadcast address from an IP and CIDR
CREATE OR REPLACE FUNCTION GET_BROADCAST_ADDRESS(ip IN VARCHAR2, cidr IN NUMBER)
RETURN VARCHAR2 IS
    ip_num NUMBER;
    mask NUMBER;
    broadcast NUMBER;
BEGIN
    ip_num := IP_TO_NUM(ip);
    mask := POWER(2, 32) - POWER(2, 32 - cidr);
    broadcast := ip_num + POWER(2, 32 - cidr) - 1;
    
    RETURN NUM_TO_IP(broadcast);
END;
/
```

2. Then install the LIST_UNWANTED_SUBNETS procedure:
```sql
CREATE OR REPLACE PROCEDURE LIST_UNWANTED_SUBNETS(
    subnet_list IN VARCHAR2,
    aggregate_subnet IN VARCHAR2,
    result_cursor OUT SYS_REFCURSOR
) IS
    TYPE subnet_rec IS RECORD (
        network_address NUMBER,
        broadcast_address NUMBER,
        cidr NUMBER
    );
    
    TYPE subnet_table IS TABLE OF subnet_rec;
    original_subnets subnet_table := subnet_table();
    
    i NUMBER := 1;
    total_subnets NUMBER;
    current_subnet VARCHAR2(50);
    original_ip VARCHAR2(15);
    original_cidr NUMBER;
    aggregate_ip VARCHAR2(15);
    aggregate_cidr NUMBER;
    smallest_cidr NUMBER := 0;
    aggregate_start NUMBER;
    aggregate_end NUMBER;
    subnet_size NUMBER;
    current_subnet_start NUMBER;
    current_subnet_end NUMBER;
    is_original BOOLEAN;
    delimiter_count NUMBER;
BEGIN
    -- Parse the aggregate subnet
    aggregate_ip := REGEXP_SUBSTR(aggregate_subnet, '[^/]+', 1, 1);
    aggregate_cidr := TO_NUMBER(REGEXP_SUBSTR(aggregate_subnet, '[^/]+', 1, 2));
    aggregate_start := IP_TO_NUM(GET_NETWORK_ADDRESS(aggregate_ip, aggregate_cidr));
    aggregate_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(aggregate_ip, aggregate_cidr));
    
    -- Count delimiter occurrences
    delimiter_count := REGEXP_COUNT(subnet_list, ',');
    total_subnets := delimiter_count + 1;
    
    -- Process each original subnet
    WHILE i <= total_subnets LOOP
        current_subnet := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
        original_ip := REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 1);
        original_cidr := TO_NUMBER(REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 2));
        
        -- Keep track of the smallest CIDR (most specific subnet)
        IF smallest_cidr = 0 OR original_cidr > smallest_cidr THEN
            smallest_cidr := original_cidr;
        END IF;
        
        -- Add to original subnets collection
        original_subnets.EXTEND;
        original_subnets(original_subnets.LAST).network_address := 
            IP_TO_NUM(GET_NETWORK_ADDRESS(original_ip, original_cidr));
        original_subnets(original_subnets.LAST).broadcast_address := 
            IP_TO_NUM(GET_BROADCAST_ADDRESS(original_ip, original_cidr));
        original_subnets(original_subnets.LAST).cidr := original_cidr;
        
        i := i + 1;
    END LOOP;
    
    -- Create a temporary table for results if it doesn't exist
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE unwanted_subnets_temp';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    
    EXECUTE IMMEDIATE 'CREATE GLOBAL TEMPORARY TABLE unwanted_subnets_temp (
        subnet VARCHAR2(50)
    ) ON COMMIT PRESERVE ROWS';
    
    -- Determine the subnet size based on the smallest CIDR
    subnet_size := POWER(2, 32 - smallest_cidr);
    
    -- Iterate through all possible subnets in the aggregate
    current_subnet_start := aggregate_start;
    
    WHILE current_subnet_start <= aggregate_end LOOP
        -- Calculate the end of this subnet
        current_subnet_end := current_subnet_start + subnet_size - 1;
        
        -- Check if this subnet is part of the original subnets
        is_original := FALSE;
        FOR j IN 1..original_subnets.COUNT LOOP
            IF original_subnets(j).network_address = current_subnet_start AND 
               original_subnets(j).broadcast_address = current_subnet_end THEN
                is_original := TRUE;
                EXIT;
            END IF;
        END LOOP;
        
        IF NOT is_original THEN
            -- This is an unwanted subnet, add it to results
            EXECUTE IMMEDIATE 'INSERT INTO unwanted_subnets_temp VALUES (:1)' 
            USING NUM_TO_IP(current_subnet_start) || '/' || smallest_cidr;
        END IF;
        
        -- Move to next subnet
        current_subnet_start := current_subnet_start + subnet_size;
    END LOOP;
    
    -- Return the results
    OPEN result_cursor FOR
        SELECT subnet FROM unwanted_subnets_temp ORDER BY subnet;
END;
/
```

## Usage

### Syntax

```sql
-- Declare a cursor variable
VARIABLE result_cursor REFCURSOR;

-- Call the procedure
EXEC LIST_UNWANTED_SUBNETS('subnet_list', 'aggregate_subnet', :result_cursor);

-- Print the results
PRINT result_cursor;
```

### Parameters

- **subnet_list**: A comma-separated list of subnet specifications in CIDR notation (e.g., '192.168.1.0/24,192.168.3.0/24')
- **aggregate_subnet**: The aggregate subnet specification in CIDR notation (e.g., '192.168.0.0/22')
- **result_cursor**: An OUT parameter that returns a cursor with the results

### Return Value

Returns a cursor pointing to a result set containing one column named 'subnet' with each row representing an unwanted subnet (in CIDR notation) included in the aggregate but not part of the original subnets.

## Examples

1. Find unwanted subnets when aggregating non-adjacent /24 subnets:
```sql
-- Declare cursor variable
VARIABLE result_cursor REFCURSOR;

-- Execute procedure
EXEC LIST_UNWANTED_SUBNETS('192.168.1.0/24,192.168.3.0/24', '192.168.0.0/22', :result_cursor);

-- Print results
PRINT result_cursor;
```
Result:
```
SUBNET
----------------
192.168.0.0/24
192.168.2.0/24
```

2. Find unwanted subnets when aggregating subnets with different prefix lengths:
```sql
-- Declare cursor variable
VARIABLE result_cursor REFCURSOR;

-- Execute procedure
EXEC LIST_UNWANTED_SUBNETS('10.0.0.0/24,10.0.3.0/24', '10.0.0.0/22', :result_cursor);

-- Print results
PRINT result_cursor;
```
Result:
```
SUBNET
-------------
10.0.1.0/24
10.0.2.0/24
```

3. Verify no unwanted subnets for perfectly aggregable subnets:
```sql
-- Declare cursor variable
VARIABLE result_cursor REFCURSOR;

-- Execute procedure
EXEC LIST_UNWANTED_SUBNETS('192.168.0.0/24,192.168.1.0/24', '192.168.0.0/23', :result_cursor);

-- Print results
PRINT result_cursor;
```
Result: Empty result set (no unwanted subnets)

## How It Works

The procedure operates in several steps:

1. **Parse Input**: 
   - Parses the original subnet list and the aggregate subnet
   - Identifies the smallest CIDR prefix length among the original subnets

2. **Create Data Structures**:
   - Creates a collection to store the network and broadcast addresses of the original subnets
   - Creates a temporary table to store the results

3. **Enumerate Subnets**:
   - Iterates through all possible subnets of the same size as the smallest original subnet that fit within the aggregate
   - For each possible subnet, checks if it matches any of the original subnets
   - If not, adds it to the list of unwanted subnets

4. **Return Results**:
   - Opens a cursor containing the list of unwanted subnets in sorted order

## Differences from MySQL Implementation

The Oracle implementation differs from the MySQL version in several ways:

1. **Result Return Method**: Oracle uses a REF CURSOR to return the result set, while MySQL directly returns a result set from the procedure.

2. **Collections vs. Temporary Tables**: Oracle uses PL/SQL collections (nested tables) to store original subnet data in memory before checking for unwanted subnets, while MySQL creates a temporary table.

3. **String Processing**: Oracle uses `REGEXP_SUBSTR` for string parsing instead of MySQL's `SUBSTRING_INDEX`.

4. **IP Conversion**: Oracle uses custom functions `IP_TO_NUM` and `NUM_TO_IP` since it lacks built-in functions like MySQL's `INET_ATON` and `INET_NTOA`.

5. **Error Handling**: The Oracle version includes exception handling for dropping the temporary table if it doesn't exist.

6. **Temporary Tables**: Oracle uses global temporary tables with the `ON COMMIT PRESERVE ROWS` option, ensuring the data remains available after the transaction.

## Notes

- The procedure identifies subnets at the same prefix length as the most specific subnet in the original list
- For large aggregates, the result set can be very large
- The procedure is useful for:
  - Planning IP addressing schemes
  - Evaluating the efficiency of route aggregation
  - Identifying free IP space within an aggregate
  - Assessing the impact of subnet summarization on routing tables
- In Oracle, to view the results, you must use the `PRINT` command after the procedure execution, or fetch from the cursor in a PL/SQL block
- The `EXECUTE IMMEDIATE` statements are used for dynamic SQL to create and manipulate the temporary table
