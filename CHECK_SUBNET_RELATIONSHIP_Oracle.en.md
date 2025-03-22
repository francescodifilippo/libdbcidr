# CHECK_SUBNET_RELATIONSHIP Function (Oracle)

This function analyzes relationships between multiple IP subnets and determines whether they meet specific criteria. The Oracle implementation returns a numeric value (1 for true, 0 for false) instead of a boolean since Oracle PL/SQL doesn't have a native boolean return type for functions.

## Documentation Languages

- [English](./CHECK_SUBNET_RELATIONSHIP_Oracle.en.md)
- [Italiano](./CHECK_SUBNET_RELATIONSHIP_Oracle.it.md)
- [Latina](./CHECK_SUBNET_RELATIONSHIP_Oracle.la.md)
- [Esperanto](./CHECK_SUBNET_RELATIONSHIP_Oracle.eo.md)

## Installation

To install this function in your Oracle database, execute the following SQL commands in order:

1. First, install the helper functions if you haven't already:
```sql
-- Convert indirizzo IP in numero
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

-- Convert numero in indirizzo IP
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

2. Then install the FIND_SUBNETS_AGGREGATE function (required for some relationship checks):
```sql
CREATE OR REPLACE FUNCTION FIND_SUBNETS_AGGREGATE(
    subnet_list IN VARCHAR2
) RETURN VARCHAR2 IS
    i NUMBER := 1;
    total_subnets NUMBER;
    current_subnet VARCHAR2(50);
    ip VARCHAR2(15);
    cidr NUMBER;
    min_ip NUMBER;
    max_ip NUMBER;
    current_ip NUMBER;
    common_bits NUMBER := 32;
    aggregate_cidr NUMBER;
    aggregate_ip NUMBER;
    delimiter_count NUMBER;
BEGIN
    -- Count delimiter occurrences
    delimiter_count := REGEXP_COUNT(subnet_list, ',');
    total_subnets := delimiter_count + 1;
    
    -- Initialize min and max IP
    current_subnet := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, 1);
    ip := REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 1);
    cidr := TO_NUMBER(REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 2));
    min_ip := IP_TO_NUM(GET_NETWORK_ADDRESS(ip, cidr));
    max_ip := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip, cidr));
    
    -- Process each subnet to find min and max IPs
    WHILE i < total_subnets LOOP
        i := i + 1;
        current_subnet := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
        ip := REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 1);
        cidr := TO_NUMBER(REGEXP_SUBSTR(current_subnet, '[^/]+', 1, 2));
        current_ip := IP_TO_NUM(GET_NETWORK_ADDRESS(ip, cidr));
        
        IF current_ip < min_ip THEN
            min_ip := current_ip;
        END IF;
        
        current_ip := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip, cidr));
        
        IF current_ip > max_ip THEN
            max_ip := current_ip;
        END IF;
    END LOOP;
    
    -- Find common bits from left to right
    common_bits := 0;
    WHILE common_bits < 32 LOOP
        IF BITAND(FLOOR(min_ip / POWER(2, 31 - common_bits)), 1) = 
           BITAND(FLOOR(max_ip / POWER(2, 31 - common_bits)), 1) THEN
            common_bits := common_bits + 1;
        ELSE
            EXIT;
        END IF;
    END LOOP;
    
    -- Calculate the aggregate CIDR
    aggregate_cidr := common_bits;
    
    -- Calculate the aggregate network address
    aggregate_ip := BITAND(min_ip, POWER(2, 32) - POWER(2, 32 - aggregate_cidr));
    
    -- Return the result
    RETURN NUM_TO_IP(aggregate_ip) || '/' || aggregate_cidr;
END;
/
```

3. Finally, install the CHECK_SUBNET_RELATIONSHIP function:
```sql
CREATE OR REPLACE FUNCTION CHECK_SUBNET_RELATIONSHIP(
    subnet_list IN VARCHAR2,
    relationship_type IN VARCHAR2
) RETURN NUMBER IS
    i NUMBER;
    j NUMBER;
    total_subnets NUMBER;
    subnet1 VARCHAR2(50);
    subnet2 VARCHAR2(50);
    ip1 VARCHAR2(15);
    ip2 VARCHAR2(15);
    cidr1 NUMBER;
    cidr2 NUMBER;
    net1_start NUMBER;
    net1_end NUMBER;
    net2_start NUMBER;
    net2_end NUMBER;
    delimiter_count NUMBER;
    aggregate VARCHAR2(50);
    aggregate_cidr NUMBER;
BEGIN
    -- Count delimiter occurrences to determine the number of subnets
    delimiter_count := REGEXP_COUNT(subnet_list, ',');
    total_subnets := delimiter_count + 1;
    
    -- If fewer than 2 subnets, certain relationships don't apply
    IF total_subnets < 2 AND relationship_type != 'VALID' THEN
        RETURN 0;
    END IF;
    
    -- Check relationships that apply to all subnet pairs
    IF relationship_type = 'ADJACENT_CHAIN' THEN
        -- Are all subnets adjacent and can form a continuous block?
        -- Assuming input is pre-sorted
        i := 1;
        WHILE i < total_subnets LOOP
            subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
            cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
            
            subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i+1);
            ip2 := REGEXP_SUBSTR(subnet2, '[^/]+', 1, 1);
            cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
            
            -- Check if the current pair is adjacent
            IF IP_TO_NUM(GET_BROADCAST_ADDRESS(ip1, cidr1)) + 1 != 
               IP_TO_NUM(GET_NETWORK_ADDRESS(ip2, cidr2)) THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'AGGREGABLE' THEN
        -- Are all subnets perfectly aggregable as a whole?
        -- First, check if all subnets have the same CIDR
        subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, 1);
        cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
        
        i := 2;
        WHILE i <= total_subnets LOOP
            subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
            
            IF cidr1 != cidr2 THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        
        -- Calculate the aggregate
        aggregate := FIND_SUBNETS_AGGREGATE(subnet_list);
        
        -- Check if the aggregate CIDR is exactly 1 bit less specific
        aggregate_cidr := TO_NUMBER(REGEXP_SUBSTR(aggregate, '[^/]+', 1, 2));
        
        -- The aggregate should be exactly one bit less specific than the original subnets
        IF aggregate_cidr != cidr1 - 1 THEN
            RETURN 0;
        END IF;
        
        -- Check if the total number of subnets is exactly 2^1 (2)
        -- This needs to be modified for multiple bits difference
        IF total_subnets != POWER(2, cidr1 - aggregate_cidr) THEN
            RETURN 0;
        END IF;
        
        RETURN 1;
        
    ELSIF relationship_type = 'ALL_DISJOINT' THEN
        -- Are all subnets disjoint (no overlapping)?
        i := 1;
        WHILE i < total_subnets LOOP
            j := i + 1;
            WHILE j <= total_subnets LOOP
                subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
                ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
                cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
                
                subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, j);
                ip2 := REGEXP_SUBSTR(subnet2, '[^/]+', 1, 1);
                cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
                
                net1_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip1, cidr1));
                net2_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip2, cidr2));
                net1_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip1, cidr1));
                net2_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip2, cidr2));
                
                -- Check if the subnets overlap
                IF NOT ((net1_end < net2_start) OR (net2_end < net1_start)) THEN
                    RETURN 0;
                END IF;
                
                j := j + 1;
            END LOOP;
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'ALL_INSIDE' THEN
        -- Are all subnets contained within a single subnet?
        -- The last subnet in the list is assumed to be the container
        subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, total_subnets);
        ip2 := REGEXP_SUBSTR(subnet2, '[^/]+', 1, 1);
        cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
        
        i := 1;
        WHILE i < total_subnets LOOP
            subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
            cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
            
            net1_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip1, cidr1));
            net1_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip1, cidr1));
            net2_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip2, cidr2));
            net2_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip2, cidr2));
            
            -- Check if subnet1 is inside subnet2
            IF NOT (net1_start >= net2_start AND net1_end <= net2_end) THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'ALL_IDENTICAL' THEN
        -- Are all subnets identical?
        subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, 1);
        ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
        cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
        
        net1_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip1, cidr1));
        net1_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip1, cidr1));
        
        i := 2;
        WHILE i <= total_subnets LOOP
            subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            ip2 := REGEXP_SUBSTR(subnet2, '[^/]+', 1, 1);
            cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
            
            net2_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip2, cidr2));
            net2_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip2, cidr2));
            
            -- Check if subnets are identical
            IF net1_start != net2_start OR net1_end != net2_end THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSIF relationship_type = 'ANY_OVERLAPPING' THEN
        -- Are any two subnets in the list overlapping?
        i := 1;
        WHILE i < total_subnets LOOP
            j := i + 1;
            WHILE j <= total_subnets LOOP
                subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
                ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
                cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
                
                subnet2 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, j);
                ip2 := REGEXP_SUBSTR(subnet2, '[^/]+', 1, 1);
                cidr2 := TO_NUMBER(REGEXP_SUBSTR(subnet2, '[^/]+', 1, 2));
                
                net1_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip1, cidr1));
                net1_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip1, cidr1));
                net2_start := IP_TO_NUM(GET_NETWORK_ADDRESS(ip2, cidr2));
                net2_end := IP_TO_NUM(GET_BROADCAST_ADDRESS(ip2, cidr2));
                
                -- Check if the subnets overlap
                IF net1_end >= net2_start AND net1_start <= net2_end THEN
                    RETURN 1;
                END IF;
                
                j := j + 1;
            END LOOP;
            i := i + 1;
        END LOOP;
        RETURN 0;
        
    ELSIF relationship_type = 'VALID' THEN
        -- Check if all subnets are valid IPv4 subnets
        i := 1;
        WHILE i <= total_subnets LOOP
            subnet1 := REGEXP_SUBSTR(subnet_list, '[^,]+', 1, i);
            ip1 := REGEXP_SUBSTR(subnet1, '[^/]+', 1, 1);
            cidr1 := TO_NUMBER(REGEXP_SUBSTR(subnet1, '[^/]+', 1, 2));
            
            -- Check if subnet is valid
            IF cidr1 < 0 OR cidr1 > 32 THEN
                RETURN 0;
            END IF;
            
            -- Check if network address matches CIDR notation
            IF IP_TO_NUM(GET_NETWORK_ADDRESS(ip1, cidr1)) != IP_TO_NUM(ip1) THEN
                RETURN 0;
            END IF;
            
            i := i + 1;
        END LOOP;
        RETURN 1;
        
    ELSE
        RETURN 0;
    END IF;
END;
/
```

## Usage

### Syntax

```sql
SELECT CHECK_SUBNET_RELATIONSHIP(subnet_list, relationship_type) FROM DUAL;
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

Returns 1 (true) or 0 (false) indicating whether the specified relationship holds for the given subnets.

## Examples

1. Check if subnets are adjacent and form a chain:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'ADJACENT_CHAIN') AS result FROM DUAL;
-- Returns 1 (true)
```

2. Check if subnets can be perfectly aggregated:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.0.0/24,192.168.1.0/24', 'AGGREGABLE') AS result FROM DUAL;
-- Returns 1 (true) because they can be aggregated to 192.168.0.0/23
```

3. Check if subnets are all inside a container subnet:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.0.0/22', 'ALL_INSIDE') AS result FROM DUAL;
-- Returns 1 (true) because both /24 subnets are inside the /22 subnet
```

4. Check if any subnets overlap:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.1.128/25', 'ANY_OVERLAPPING') AS result FROM DUAL;
-- Returns 1 (true) because 192.168.1.0/24 overlaps with 192.168.1.128/25
```

5. Check if all subnets are valid:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'VALID') AS result FROM DUAL;
-- Returns 1 (true) because all subnets are valid
```

## Differences from MySQL Implementation

The Oracle implementation differs from the MySQL version in several ways:

1. **Return Type**: Oracle functions can't return a boolean value directly, so this function returns 1 for true and 0 for false.

2. **String Processing**: Oracle uses `REGEXP_SUBSTR` for string parsing instead of MySQL's `SUBSTRING_INDEX`.

3. **IP Conversion**: Since Oracle doesn't have built-in functions like `INET_ATON` and `INET_NTOA`, we use custom functions `IP_TO_NUM` and `NUM_TO_IP`.

4. **Bit Manipulation**: Oracle uses `BITAND` for bitwise AND operations, and different logic for bit shifting since it doesn't have direct bit-shift operators.

5. **Control Flow**: Oracle uses `IF-ELSIF-ELSE` constructs instead of MySQL's `CASE` statements for the main relationship logic.

## Notes

- The function assumes that subnet specifications are in the correct format.
- For 'ADJACENT_CHAIN', the subnets should be provided in order.
- The 'AGGREGABLE' check works best when all subnets have the same CIDR prefix length.
- When using 'ALL_INSIDE', the containing subnet should be the last one in the list.
- Oracle PL/SQL requires that all statements have a semicolon (;) terminator, and functions end with a forward slash (/) to indicate the end of the function definition.
