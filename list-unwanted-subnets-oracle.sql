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