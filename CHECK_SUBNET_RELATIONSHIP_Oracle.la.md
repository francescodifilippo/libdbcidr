# Functio CHECK_SUBNET_RELATIONSHIP (Oracle)

Haec functio relationes inter plures subretes IP examinat et determinat si criteria specifica satisfaciunt.

## Linguae Documentationis

- [English](./CHECK_SUBNET_RELATIONSHIP_Oracle.en.md)
- [Italiano](./CHECK_SUBNET_RELATIONSHIP_Oracle.it.md)
- [Latina](./CHECK_SUBNET_RELATIONSHIP_Oracle.la.md)
- [Esperanto](./CHECK_SUBNET_RELATIONSHIP_Oracle.eo.md)

## Installatio

Ad hanc functionem in base dati Oracle installandam, hos iussos SQL per ordinem exequere:

1. Primum, functiones auxiliares installa si nondum fecisti:
[`HELPER_FUNCTIONS_Oracle.sql`](./sql/HELPER_FUNCTIONS_Oracle.sql)

2. Deinde installa functionem FIND_SUBNETS_AGGREGATE (necessaria pro quibusdam relationum inspectionibus):
[`FIND_SUBNETS_AGGREGATE_Oracle.sql`](./sql/FIND_SUBNETS_AGGREGATE_Oracle.sql)

3. Tandem, installa functionem CHECK_SUBNET_RELATIONSHIP:
[`CHECK_SUBNET_RELATIONSHIP_Oracle.sql`](./sql/CHECK_SUBNET_RELATIONSHIP_Oracle.sql)

## Usus

### Syntaxis

```sql
SELECT CHECK_SUBNET_RELATIONSHIP(subnet_list, relationship_type) FROM DUAL;
```

### Parametri

- **subnet_list**: Lista specificationum subretium separatarum per comma in notatione CIDR (e.g., '192.168.1.0/24,192.168.2.0/24')
- **relationship_type**: Typus relationis inspiciendae. Valores validi sunt:
  - 'ADJACENT_CHAIN': Inspicit si omnes subretes formant catenam continuam
  - 'AGGREGABLE': Inspicit si omnes subretes possunt perfecte aggregari
  - 'ALL_DISJOINT': Inspicit si omnes subretes sunt disiunctae (nulla superpositio)
  - 'ALL_INSIDE': Inspicit si omnes subretes continentur intra ultimam subretem in lista
  - 'ALL_IDENTICAL': Inspicit si omnes subretes sunt identicae
  - 'ANY_OVERLAPPING': Inspicit si duae subretes quaecumque in lista superponunt
  - 'VALID': Inspicit si omnes subretes sunt subretes IPv4 validae

### Valor Reditus

Reddit NUMBER (1 vel 0) indicans si relatio specificata valet pro subretibus datis.

## Exempla

1. Inspice si subretes sunt adiacentes et formant catenam:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'ADJACENT_CHAIN') FROM DUAL;
-- Reddit 1 (VERUM)
```

2. Inspice si subretes possunt perfecte aggregari:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.0.0/24,192.168.1.0/24', 'AGGREGABLE') FROM DUAL;
-- Reddit 1 (VERUM) quia possunt aggregari in 192.168.0.0/23
```

3. Inspice si subretes sunt omnes intra subretem continentem:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.0.0/22', 'ALL_INSIDE') FROM DUAL;
-- Reddit 1 (VERUM) quia ambae subretes /24 sunt intra subretem /22
```

4. Inspice si sunt subretes quae superponunt:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.1.128/25', 'ANY_OVERLAPPING') FROM DUAL;
-- Reddit 1 (VERUM) quia 192.168.1.0/24 superponit cum 192.168.1.128/25
```

5. Inspice si omnes subretes sunt validae:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'VALID') FROM DUAL;
-- Reddit 1 (VERUM) quia omnes subretes sunt validae
```

## Notae

- Functio assumit specificationes subretium esse in formato correcto.
- Pro 'ADJACENT_CHAIN', subretes deberent praeberi in ordine.
- Inspectio 'AGGREGABLE' optime operatur quando omnes subretes habent eandem longitudinem praefixae CIDR.
- Quando uteris 'ALL_INSIDE', subres continens deberet esse ultima in lista.
- In Oracle, functio reddit 1 pro VERO et 0 pro FALSO, dissimiliter a MySQL quae reddit valores booleanos directos.
