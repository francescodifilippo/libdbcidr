# IP Subnet Management Functions

A collection of SQL functions for managing, analyzing, and manipulating IP subnets in MySQL and Oracle databases.

## Project History

This project began in 2004 with the development of `libmysqlcidr` and `liboraclecidr`, two C modules for MySQL and Oracle databases respectively. At that time, neither database offered native functions for IP address manipulation:

- MySQL lacked `INET_ATON()`, `INET_NTOA()`, `INET6_ATON()`, and `INET6_NTOA()` functions
- Oracle had no equivalent to the `UTL_INADDR` package

MySQL did allow bit shift operations which could be used for IP calculations, but Oracle lacked even these capabilities, making IP subnet management particularly challenging.

The original C modules provided efficient tools for subnet calculations and comparisons, filling a critical gap in database functionality for network management applications.

Today, both MySQL and Oracle include native functions for IP address handling, making the original C modules less necessary. However, the advanced subnet relationship analysis functions remain valuable and have been converted from C to native SQL functions for easier integration and maintenance.

## Purpose

These functions allow database administrators and developers to perform advanced subnet operations directly within the database, eliminating the need for external processing and simplifying network management tasks.

Key capabilities include:

1. **Relationship Analysis**: Check various types of relationships between multiple IP subnets (adjacency, containment, overlap)
2. **Aggregation**: Find the optimal aggregate subnet that encompasses multiple subnets
3. **Gap Analysis**: Identify unwanted subnets that would be included in an aggregate

These capabilities support critical network management tasks such as:
- IPAM (IP Address Management)
- Network planning and optimization
- Firewall rule analysis and consolidation
- Routing table optimization
- IP address migration planning

## Function Documentation

### MySQL Functions

- [CHECK_SUBNET_RELATIONSHIP (MySQL)](./CHECK_SUBNET_RELATIONSHIP_MySQL.en.md)
- [FIND_SUBNETS_AGGREGATE (MySQL)](./FIND_SUBNETS_AGGREGATE_MySQL.en.md)
- [LIST_UNWANTED_SUBNETS (MySQL)](./LIST_UNWANTED_SUBNETS_MySQL.en.md)
- [Helper Functions (MySQL)](./HELPER_FUNCTIONS_MySQL.en.md)

### Oracle Functions

- [CHECK_SUBNET_RELATIONSHIP (Oracle)](./CHECK_SUBNET_RELATIONSHIP_Oracle.en.md)
- [FIND_SUBNETS_AGGREGATE (Oracle)](./FIND_SUBNETS_AGGREGATE_Oracle.en.md)
- [LIST_UNWANTED_SUBNETS (Oracle)](./LIST_UNWANTED_SUBNETS_Oracle.en.md)
- [Helper Functions (Oracle)](./HELPER_FUNCTIONS_Oracle.en.md)

## Installation

See the documentation for each specific function for detailed installation instructions for your database platform.

## License

This project is open source and available under the MIT License.
