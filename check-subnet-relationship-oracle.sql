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