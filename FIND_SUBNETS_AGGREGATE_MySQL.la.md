
# Functio FIND_SUBNETS_AGGREGATE (MySQL)

Haec functio calculat minimam subretem aggregatam quae omnes subretes IP provisas comprehendit.

## Linguae Documentationis

- [English](./FIND_SUBNETS_AGGREGATE_MySQL.en.md)
- [Italiano](./FIND_SUBNETS_AGGREGATE_MySQL.it.md)
- [Latina](./FIND_SUBNETS_AGGREGATE_MySQL.la.md)
- [Esperanto](./FIND_SUBNETS_AGGREGATE_MySQL.eo.md)

## Installatio

Ad hanc functionem in base dati MySQL installandam, hos iussos SQL per ordinem exequere:

1. Primum, functiones auxiliares installa si nondum fecisti:
[`HELPER_FUNCTIONS_MySQL.sql`](./sql/HELPER_FUNCTIONS_MySQL.sql)

2. Deinde installa functionem FIND_SUBNETS_AGGREGATE:
[`FIND_SUBNETS_AGGREGATE_MySQL.sql`](./sql/FIND_SUBNETS_AGGREGATE_MySQL.sql)

## Usus

### Syntaxis

```sql
SELECT FIND_SUBNETS_AGGREGATE(subnet_list);
```

### Parametri

- **subnet_list**: Lista specificationum subretium separatarum per comma in notatione CIDR (e.g., '192.168.1.0/24,192.168.2.0/24')

### Valor Reditus

Reddit catenam repraesentantem minimam subretem aggregatam (in notatione CIDR) quae omnes subretes provisas comprehendit.

## Exempla

1. Inveni aggregatum duarum subretium /24 adiacentium:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,192.168.1.0/24');
-- Reddit '192.168.0.0/23'
```

2. Inveni aggregatum subretium non adiacentium:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24,192.168.3.0/24');
-- Reddit '192.168.0.0/22'
```

3. Inveni aggregatum subretium cum diversis longitudinibus CIDR:
```sql
SELECT FIND_SUBNETS_AGGREGATE('10.0.0.0/24,10.0.1.0/24,10.0.2.0/23');
-- Reddit '10.0.0.0/22'
```

4. Inveni aggregatum subretium ex diversis spatiis inscriptionum:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,10.0.0.0/24');
-- Reddit '0.0.0.0/0' (totum spatium inscriptionum IPv4)
```

5. Inveni aggregatum unius subretis (reddit eandem subretem):
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24');
-- Reddit '192.168.1.0/24'
```

## Quomodo Operatur

Functio operatur in pluribus gradibus:

1. **Examina elenchum subretium**: Dividit elenchum separatum per commata et numerat numerum subretium.

2. **Invenit inscriptiones IP minimas et maximas**: 
   - Convertit quamque subretem in suam inscriptionem retis et inscriptionem divulgationis
   - Vestigat inscriptionem retis minimam et inscriptionem divulgationis maximam

3. **Calculat praefixum commune**:
   - Incipiens a bit maxime sinistrorsum, numerat quot bits identici sunt inter inscriptionem IP minimam et maximam
   - Hic numerus fit longitudo praefixae CIDR pro subrete aggregata

4. **Computat inscriptionem retis**:
   - Applicat personam derivatam a longitudine praefixae ad inscriptionem IP minimam
   - Hoc assecurat inscriptionem retis recte alineatam esse ad limitem CIDR

5. **Generat notationem CIDR**:
   - Coniungit inscriptionem retis cum longitudine praefixae ad creandam specificationem subretis aggregatae

## Notae

- Functio semper reddit aggregatum minimum possibile quod continet omnes subretes input.
- Quando subretes longe distant, aggregatum potest includere numerum significantem inscriptionum IP non desideratarum.
- Pro subretibus ex diversis blocis principalibus (e.g., 10.x.x.x et 192.168.x.x), aggregatum erit valde magnum.
- Ad identificandas subretes non desideratas inclusas in aggregato, utere proceduram `LIST_UNWANTED_SUBNETS`.
