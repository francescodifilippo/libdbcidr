# Functio CHECK_SUBNET_RELATIONSHIP (MySQL)

Haec functio examinat relationes inter plures subretes IP et determinat utrum criteria specifica implent.

## Linguae Documentationis

- [English](./CHECK_SUBNET_RELATIONSHIP_MySQL.en.md)
- [Italiano](./CHECK_SUBNET_RELATIONSHIP_MySQL.it.md)
- [Latina](./CHECK_SUBNET_RELATIONSHIP_MySQL.la.md)
- [Esperanto](./CHECK_SUBNET_RELATIONSHIP_MySQL.eo.md)

## Installatio

Ad hanc functionem in tua base datorum MySQL installandam, exsequere haec mandata SQL per ordinem:

1. Primo, installa functiones auxiliares si nondum fecisti:
[`HELPER_FUNCTIONS_MySQL.sql`](./sql/HELPER_FUNCTIONS_MySQL.sql)

2. Deinde installa functionem FIND_SUBNETS_AGGREGATE (necessariam pro quibusdam relationum examinationibus):
[`FIND_SUBNETS_AGGREGATE_MySQL.sql`](./sql/FIND_SUBNETS_AGGREGATE_MySQL.sql)

3. Tandem, installa functionem CHECK_SUBNET_RELATIONSHIP:
[`CHECK_SUBNET_RELATIONSHIP_MySQL.sql`](./sql/CHECK_SUBNET_RELATIONSHIP_MySQL.sql)

## Usus

### Syntaxis

```sql
SELECT CHECK_SUBNET_RELATIONSHIP(subnet_list, relationship_type);
```

### Parametri

- **subnet_list**: Elenchus subretium separatarum per commata in notatione CIDR (e.g., '192.168.1.0/24,192.168.2.0/24')
- **relationship_type**: Typus relationis examinandae. Valores validi sunt:
  - 'ADJACENT_CHAIN': Examinat si omnes subretes formant catenam continuam
  - 'AGGREGABLE': Examinat si omnes subretes possunt perfecte aggregari
  - 'ALL_DISJOINT': Examinat si omnes subretes sunt disiunctae (sine superpositione)
  - 'ALL_INSIDE': Examinat si omnes subretes continentur intra ultimam subretem in elencho
  - 'ALL_IDENTICAL': Examinat si omnes subretes sunt identicae
  - 'ANY_OVERLAPPING': Examinat si duae subretes quaelibet in elencho superponuntur
  - 'VALID': Examinat si omnes subretes sunt validae subretes IPv4

### Valor Reditus

Reddit BOOLEAN (1 vel 0) indicans utrum relatio specificata valet pro subretibus datis.

## Exempla

1. Examina si subretes sunt adiacentes et formant catenam:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'ADJACENT_CHAIN');
-- Reddit 1 (VERUM)
```

2. Examina si subretes possunt perfecte aggregari:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.0.0/24,192.168.1.0/24', 'AGGREGABLE');
-- Reddit 1 (VERUM) quia possunt aggregari ad 192.168.0.0/23
```

3. Examina si subretes sunt omnes intra subretem continentem:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.0.0/22', 'ALL_INSIDE');
-- Reddit 1 (VERUM) quia ambae subretes /24 sunt intra subretem /22
```

4. Examina si aliquae subretes superponuntur:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.1.128/25', 'ANY_OVERLAPPING');
-- Reddit 1 (VERUM) quia 192.168.1.0/24 superponit cum 192.168.1.128/25
```

5. Examina si omnes subretes sunt validae:
```sql
SELECT CHECK_SUBNET_RELATIONSHIP('192.168.1.0/24,192.168.2.0/24,192.168.3.0/24', 'VALID');
-- Reddit 1 (VERUM) quia omnes subretes sunt validae
```

## Notae

- Functio supponit specificationes subretium esse in formato correcto.
- Pro 'ADJACENT_CHAIN', subretes debent praeberi in ordine.
- Examinatio 'AGGREGABLE' optime operatur quando omnes subretes habent eandem longitudinem praefixorum CIDR.
- Quando utens 'ALL_INSIDE', subretis continens debet esse ultima in elencho.
