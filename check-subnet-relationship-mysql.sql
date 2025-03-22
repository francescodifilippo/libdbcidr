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