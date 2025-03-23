# Procedura LIST_UNWANTED_SUBNETS (MySQL)

Questa procedura identifica le subnet che sarebbero incluse in un aggregato ma non fanno parte dell'elenco originale delle subnet. Aiuta gli amministratori di rete ad analizzare lo "spreco" quando si aggregano subnet non contigue.

## Lingue della Documentazione

- [English](./LIST_UNWANTED_SUBNETS_MySQL.en.md)
- [Italiano](./LIST_UNWANTED_SUBNETS_MySQL.it.md)
- [Latina](./LIST_UNWANTED_SUBNETS_MySQL.la.md)
- [Esperanto](./LIST_UNWANTED_SUBNETS_MySQL.eo.md)

## Installazione

Per installare questa procedura nel tuo database MySQL, esegui i seguenti comandi SQL in ordine:

1. Prima, installa le funzioni di supporto se non l'hai già fatto:
[`HELPER_FUNCTIONS_MySQL.sql`](./sql/HELPER_FUNCTIONS_MySQL.sql)

2. Quindi installa la procedura LIST_UNWANTED_SUBNETS:
[`LIST_UNWANTED_SUBNETS_MySQL.sql`](./sql/LIST_UNWANTED_SUBNETS_MySQL.sql)

## Utilizzo

### Sintassi

```sql
CALL LIST_UNWANTED_SUBNETS(subnet_list, aggregate_subnet);
```

### Parametri

- **subnet_list**: Un elenco di specifiche di subnet separate da virgola in notazione CIDR (es., '192.168.1.0/24,192.168.3.0/24')
- **aggregate_subnet**: La specifica della subnet aggregata in notazione CIDR (es., '192.168.0.0/22')

### Valore di Ritorno

Restituisce un insieme di risultati contenente una colonna denominata 'subnet' con ogni riga che rappresenta una subnet indesiderata (in notazione CIDR) inclusa nell'aggregato ma non facente parte delle subnet originali.

## Esempi

1. Trovare le subnet indesiderate quando si aggregano subnet /24 non adiacenti:
```sql
CALL LIST_UNWANTED_SUBNETS('192.168.1.0/24,192.168.3.0/24', '192.168.0.0/22');
```
Risultato:
```
+----------------+
| subnet         |
+----------------+
| 192.168.0.0/24 |
| 192.168.2.0/24 |
+----------------+
```

2. Trovare le subnet indesiderate quando si aggregano subnet con lunghezze di prefisso diverse:
```sql
CALL LIST_UNWANTED_SUBNETS('10.0.0.0/24,10.0.3.0/24', '10.0.0.0/22');
```
Risultato:
```
+-------------+
| subnet      |
+-------------+
| 10.0.1.0/24 |
| 10.0.2.0/24 |
+-------------+
```

3. Verificare che non ci siano subnet indesiderate per subnet perfettamente aggregabili:
```sql
CALL LIST_UNWANTED_SUBNETS('192.168.0.0/24,192.168.1.0/24', '192.168.0.0/23');
```
Risultato: Insieme di risultati vuoto (nessuna subnet indesiderata)

4. Trovare le subnet indesiderate in un grande aggregato:
```sql
CALL LIST_UNWANTED_SUBNETS('10.0.0.0/24,192.168.0.0/24', '0.0.0.0/0');
```
Risultato: Insieme di risultati molto grande contenente tutte le reti /24 nello spazio IPv4 tranne le due specificate.

## Come Funziona

La procedura opera in diverse fasi:

1. **Analisi dell'Input**: 
   - Analizza l'elenco delle subnet originali e la subnet aggregata
   - Identifica la lunghezza del prefisso CIDR più piccola (più specifica) tra le subnet originali

2. **Creazione delle Strutture Dati**:
   - Crea una tabella temporanea per memorizzare gli indirizzi di rete e broadcast delle subnet originali
   - Crea una tabella temporanea per memorizzare i risultati

3. **Enumerazione delle Subnet**:
   - Itera attraverso tutte le possibili subnet della stessa dimensione della subnet originale più specifica che si adattano all'interno dell'aggregato
   - Per ogni possibile subnet, verifica se corrisponde a una delle subnet originali
   - In caso contrario, la aggiunge all'elenco delle subnet indesiderate

4. **Restituzione dei Risultati**:
   - Restituisce l'elenco delle subnet indesiderate in ordine ordinato

## Note

- La procedura identifica le subnet alla stessa lunghezza di prefisso della subnet più specifica nell'elenco originale
- Per aggregati grandi, l'insieme dei risultati può essere molto grande
- La procedura è utile per:
  - Pianificazione degli schemi di indirizzi IP
  - Valutazione dell'efficienza dell'aggregazione delle rotte
  - Identificazione dello spazio IP libero all'interno di un aggregato
  - Valutazione dell'impatto della summarizzazione delle subnet sulle tabelle di routing
