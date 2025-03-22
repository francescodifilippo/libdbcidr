# Functiones Administrationis Subretium IP

Collectio functionum SQL ad administrandum, examinandum, et tractandum subretes IP in basibus datorum MySQL et Oracle.

## Historia Projecti

Hoc projectum inceptum est anno 2004 cum evolutione `libmysqlcidr` et `liboraclecidr`, duo moduli C pro basibus datorum MySQL et Oracle respective. Illo tempore, neuter basis datorum functiones nativas ad manipulationem inscriptionum IP praebebat:

- MySQL carebat functionibus `INET_ATON()`, `INET_NTOA()`, `INET6_ATON()`, et `INET6_NTOA()`
- Oracle nihil simile pachetae `UTL_INADDR` habebat

MySQL permittebat operationes translationis bitorum quae ad calculos IP adhiberi poterant, sed Oracle etiam his facultatibus carebat, faciens administrationem subretium IP particulatim difficilem.

Moduli C originales instrumenta efficientia ad calculos subretium et comparationes praebebant, implentes lacunam criticam in functionalitate basium datorum pro applicationibus administrationis retis.

Hodie, et MySQL et Oracle functiones nativas ad tractationem inscriptionum IP includunt, facientes modulos C originales minus necessarios. Tamen, functiones progressae analyseos relationum subretium adhuc pretiosae manent et e C ad functiones nativas SQL conversae sunt pro faciliore integratione et manutentione.

## Propositum

Hae functiones permittunt administratoribus basium datorum et programmatoribus ut operationes progressas subretium directe intra basim datorum exequantur, eliminantes necessitatem processus externi et simplificantes munera administrationis retis.

Facultates principales includunt:

1. **Analysis Relationum**: Verificare varios typos relationum inter multiplices subretes IP (adiacentiam, inclusionem, superpositionem)
2. **Aggregatio**: Invenire subretem aggregatam optimam quae multiplices subretes comprehendat
3. **Analysis Lacunarum**: Identificare subretes indesideratas quae in aggregatione includerentur

Hae facultates sustinent munera critica administrationis retis sicut:
- IPAM (Administratio Inscriptionum IP)
- Planificatio et optimizatio retis
- Analysis et consolidatio regularum muri ignis
- Optimizatio tabularum dirigendi
- Planificatio migrationis inscriptionum IP

## Documentatio Functionum

### Functiones MySQL

- [CHECK_SUBNET_RELATIONSHIP (MySQL)](./CHECK_SUBNET_RELATIONSHIP_MySQL.la.md)
- [FIND_SUBNETS_AGGREGATE (MySQL)](./FIND_SUBNETS_AGGREGATE_MySQL.la.md)
- [LIST_UNWANTED_SUBNETS (MySQL)](./LIST_UNWANTED_SUBNETS_MySQL.la.md)
- [Functiones Auxiliares (MySQL)](./HELPER_FUNCTIONS_MySQL.la.md)

### Functiones Oracle

- [CHECK_SUBNET_RELATIONSHIP (Oracle)](./CHECK_SUBNET_RELATIONSHIP_Oracle.la.md)
- [FIND_SUBNETS_AGGREGATE (Oracle)](./FIND_SUBNETS_AGGREGATE_Oracle.la.md)
- [LIST_UNWANTED_SUBNETS (Oracle)](./LIST_UNWANTED_SUBNETS_Oracle.la.md)
- [Functiones Auxiliares (Oracle)](./HELPER_FUNCTIONS_Oracle.la.md)

## Installatio

Vide documentationem cuiusque functionis specificae pro instructionibus detallatis installationis pro tua platforma basis datorum.

## Licentia

Hoc projectum est fontis aperti et disponibile sub Licentia MIT.
