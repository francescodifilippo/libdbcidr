# Functio FIND_SUBNETS_AGGREGATE (Oracle)

Haec functio calculat subretem minimam aggregatam quae omnes subretes IP datas comprehendit.

## Linguae Documentationis

- [Anglica](./FIND_SUBNETS_AGGREGATE_Oracle.en.md)
- [Italica](./FIND_SUBNETS_AGGREGATE_Oracle.it.md)
- [Latina](./FIND_SUBNETS_AGGREGATE_Oracle.la.md)
- [Esperanto](./FIND_SUBNETS_AGGREGATE_Oracle.eo.md)

## Installatio

Ad hanc functionem in base datorum Oracle installandam, primum functiones auxiliares installare debes si nondum eas habes. Deinde, functionem FIND_SUBNETS_AGGREGATE ipsam installare potes.

Omnes codicem SQL necessarium in archivo [`FIND_SUBNETS_AGGREGATE_Oracle.sql`](./sql/FIND_SUBNETS_AGGREGATE_Oracle.sql) invenies.

## Usus

### Syntaxis

```sql
SELECT FIND_SUBNETS_AGGREGATE(subnet_list) FROM DUAL;
```

### Parametri

- **subnet_list**: Elenchus subretium separatus commatis in notatione CIDR (e.g., '192.168.1.0/24,192.168.2.0/24')

### Valor Redditus

Reddit catenam representantem subretem minimam aggregatam (in notatione CIDR) quae omnes subretes datas comprehendit.

## Exempla

1. Invenire aggregatum duarum subretium /24 adiacentium:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,192.168.1.0/24') FROM DUAL;
-- Reddit '192.168.0.0/23'
```

2. Invenire aggregatum subretium non adiacentium:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24,192.168.3.0/24') FROM DUAL;
-- Reddit '192.168.0.0/22'
```

3. Invenire aggregatum subretium cum diversis longitudinibus CIDR:
```sql
SELECT FIND_SUBNETS_AGGREGATE('10.0.0.0/24,10.0.1.0/24,10.0.2.0/23') FROM DUAL;
-- Reddit '10.0.0.0/22'
```

4. Invenire aggregatum subretium ex diversis spatiis addressarum:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,10.0.0.0/24') FROM DUAL;
-- Reddit '0.0.0.0/0' (totum spatium addressarum IPv4)
```

5. Invenire aggregatum unius subretis (reddit eandem subretem):
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24') FROM DUAL;
-- Reddit '192.168.1.0/24'
```

## Quomodo Functio Operatur

Functio in pluribus gradibus operatur:

1. **Analyzare elenchum subretium**: Dividit elenchum commatis separatum et numerat numerum subretium.

2. **Invenire addressas IP minimas et maximas**: 
   - Convertit unamquamque subretem in suam addressam retis et addressam emissionis
   - Servat minimam addressam retis et maximam addressam emissionis

3. **Calculare praefixum commune**:
   - Incipiens a bit sinistro extremo, numerat quot bits identici sunt inter addressas IP minimas et maximas
   - Hic numerus fit longitudo praefixae CIDR pro subrete aggregata

4. **Computare addressam retis**:
   - Applicat mascam derivatam ex longitudine praefixae ad addressam IP minimam
   - Hoc asserit addressam retis recte alignatam esse ad terminum CIDR

5. **Generare notationem CIDR**:
   - Combinat addressam retis cum longitudine praefixae ad creandam specificationem subretis aggregatae

## Notae

- Functio semper reddit aggregatum minimum possibile quod omnes subretes input continet.
- Quando subretes longe distant, aggregatum potest includere numerum significantem addressarum IP non desideratarum.
- Pro subretibus ex diversis magnis partibus (e.g., 10.x.x.x et 192.168.x.x), aggregatum erit valde magnum.
- Ad identificandas subretes non desideratas inclusas in aggregato, utere procedura `LIST_UNWANTED_SUBNETS`.
