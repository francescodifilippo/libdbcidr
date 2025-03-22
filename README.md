# IP Subnet Management Functions

A collection of SQL functions for managing, analyzing, and manipulating IP subnets in MySQL and Oracle databases.

> **IMPORTANT NOTICE**: This project is currently a pre-release in alpha test. The functions may contain bugs, undergo significant changes, and are not yet recommended for production environments. Please report any issues on our GitHub repository.

## Documentation Languages

- [English](./README.en.md)
- [Italiano](./README.it.md)
- [Latina](./README.la.md)
- [Esperanto](./README.eo.md)

## Project Status

This project is currently in **alpha testing phase**. Key considerations:

- Functions are being actively tested and refined
- API may change without backward compatibility
- Performance optimizations are still in progress
- Not all edge cases have been fully tested
- Documentation is being completed for all functions and languages

We welcome testers and contributors who can help identify issues and suggest improvements. Please use the GitHub issue tracker to report bugs or unexpected behavior.

## Project History

This project began in 2004 with the development of `libmysqlcidr` and `liboraclecidr`, two C modules for MySQL and Oracle databases respectively. At that time, neither database offered native functions for IP address manipulation. MySQL allowed bit shift operations which could be used for IP calculations, but Oracle lacked even these capabilities.

The original C modules provided efficient tools for subnet calculations and comparisons, filling a critical gap in database functionality for network management applications.

Today, both MySQL and Oracle include native functions for IP address handling (`INET_ATON()`, `INET_NTOA()`, `INET6_ATON()`, and `INET6_NTOA()` in MySQL; and `UTL_INADDR` package in Oracle), making the original C modules less necessary. However, the advanced subnet relationship analysis functions remain valuable and have been converted from C to native SQL functions for easier integration and maintenance.

## Purpose

These functions allow database administrators and developers to:
1. Check relationships between multiple IP subnets (adjacency, containment, overlap)
2. Find the optimal aggregate subnet that encompasses multiple subnets
3. Identify unwanted subnets that would be included in an aggregate

The functions support critical network management tasks such as:
- IPAM (IP Address Management)
- Network planning and optimization
- Firewall rule analysis and optimization
- Routing table optimization

## Function Documentation

### MySQL Functions

- [CHECK_SUBNET_RELATIONSHIP (MySQL)](./CHECK_SUBNET_RELATIONSHIP_MySQL.md)
- [FIND_SUBNETS_AGGREGATE (MySQL)](./FIND_SUBNETS_AGGREGATE_MySQL.md)
- [LIST_UNWANTED_SUBNETS (MySQL)](./LIST_UNWANTED_SUBNETS_MySQL.md)
- [Helper Functions (MySQL)](./HELPER_FUNCTIONS_MySQL.md)

### Oracle Functions

- [CHECK_SUBNET_RELATIONSHIP (Oracle)](./CHECK_SUBNET_RELATIONSHIP_Oracle.md)
- [FIND_SUBNETS_AGGREGATE (Oracle)](./FIND_SUBNETS_AGGREGATE_Oracle.md)
- [LIST_UNWANTED_SUBNETS (Oracle)](./LIST_UNWANTED_SUBNETS_Oracle.md)
- [Helper Functions (Oracle)](./HELPER_FUNCTIONS_Oracle.md)

## License

This project is open source and available under the MIT License.
