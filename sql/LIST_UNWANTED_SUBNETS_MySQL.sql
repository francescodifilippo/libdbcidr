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