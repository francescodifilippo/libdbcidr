# Procedura LIST_UNWANTED_SUBNETS (MySQL)

Haec procedura identificat subretes quae in aggregatione includerentur sed non sunt pars elenchi subretium originalis. Adiuvat administratores retis ad analysandum "dispendium" cum subretes non contiguae aggregantur.

## Linguae Documentationis

- [English](./LIST_UNWANTED_SUBNETS_MySQL.en.md)
- [Italiano](./LIST_UNWANTED_SUBNETS_MySQL.it.md)
- [Latina](./LIST_UNWANTED_SUBNETS_MySQL.la.md)
- [Esperanto](./LIST_UNWANTED_SUBNETS_MySQL.eo.md)

## Installatio

Ad hanc proceduram in tua base datorum MySQL installandam, exsequere haec mandata SQL per ordinem:

1. Primo, installa functiones auxiliares si nondum fecisti:
[`HELPER_FUNCTIONS_MySQL.sql`](./sql/HELPER_FUNCTIONS_MySQL.sql)

2. Deinde installa proceduram LIST_UNWANTED_SUBNETS:
[`LIST_UNWANTED_SUBNETS_MySQL.sql`](./sql/LIST_UNWANTED_SUBNETS_MySQL.sql)

## Usus

### Syntaxis

```sql
CALL LIST_UNWANTED_SUBNETS(subnet_list, aggregate_subnet);
```

### Parametri

- **subnet_list**: Elenchus subretium separatarum per commata in notatione CIDR (e.g., '192.168.1.0/24,192.168.3.0/24')
- **aggregate_subnet**: Specificatio subretis aggregatae in notatione CIDR (e.g., '192.168.0.0/22')

### Valor Reditus

Reddit resultatum continentem unam columnam nominatam 'subnet' cum unaquaque linea repraesentante subretem indesideratam (in notatione CIDR) inclusam in aggregatione sed non partem subretium originalium.

## Exempla

1. Inveni subretes indesideratas cum aggregas subretes /24 non contiguas:
```sql
CALL LIST_UNWANTED_SUBNETS('192.168.1.0/24,192.168.3.0/24', '192.168.0.0/22');
```
Resultatum:
```
+----------------+
| subnet         |
+----------------+
| 192.168.0.0/24 |
| 192.168.2.0/24 |
+----------------+
```

2. Inveni subretes indesideratas cum aggregas subretes cum diversis longitudinibus praefixorum:
```sql
CALL LIST_UNWANTED_SUBNETS('10.0.0.0/24,10.0.3.0/24', '10.0.0.0/22');
```
Resultatum:
```
+-------------+
| subnet      |
+-------------+
| 10.0.1.0/24 |
| 10.0.2.0/24 |
+-------------+
```

3. Verifica nullas subretes indesideratas pro subretibus perfecte aggregabilibus:
```sql
CALL LIST_UNWANTED_SUBNETS('192.168.0.0/24,192.168.1.0/24', '192.168.0.0/23');
```
Resultatum: Resultatum vacuum (nullae subretes indesideratae)

4. Inveni subretes indesideratas in aggregatione magna:
```sql
CALL LIST_UNWANTED_SUBNETS('10.0.0.0/24,192.168.0.0/24', '0.0.0.0/0');
```
Resultatum: Resultatum valde magnum continens omnes retes /24 in spatio IPv4 exceptis duabus specificatis.

## Quomodo Procedura Operatur

Procedura operatur per plures gradus:

1. **Analysis Ingressus**: 
   - Analysat elenchum subretium originalem et subretem aggregatam
   - Identificat longitudinem praefixorum CIDR minime specificam (maximum) inter subretes originales

2. **Creatio Structurarum Datorum**:
   - Creat tabulam temporariam ad servandum inscriptiones retium et divulgationum subretium originalium
   - Creat tabulam temporariam ad servanda resultata

3. **Enumeratio Subretium**:
   - Iterat per omnes subretes possibiles eiusdem magnitudinis ac subretis originalibus maxime specificis quae cadunt intra aggregationem
   - Pro quaque subrete possibili, verificat si congruit cum aliqua subreti originali
   - Si non, addit ad elenchum subretium indesideratarum

4. **Redditio Resultatorum**:
   - Reddit elenchum subretium indesideratarum in ordine ordinato

## Notae

- Procedura identificat subretes ad eandem longitudinem praefixorum ac subretis maxime specifica in elencho originali
- Pro aggregationibus magnis, resultatum potest esse valde magnum
- Procedura est utilis pro:
  - Planificatione schematum inscriptionum IP
  - Aestimatione efficientiae aggregationis viarium
  - Identificatione spatii IP liberi intra aggregationem
  - Aestimatione impactus summarizationis subretium in tabulis directorialibus
