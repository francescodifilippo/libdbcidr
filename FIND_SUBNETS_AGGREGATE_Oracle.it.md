# Funzione FIND_SUBNETS_AGGREGATE (Oracle)

Questa funzione calcola la subnet aggregata minima che comprende tutte le subnet IP fornite. L'implementazione Oracle gestisce la manipolazione delle stringhe e le operazioni bit a bit in modo diverso rispetto alla versione MySQL a causa delle differenze nelle funzioni integrate disponibili.

## Lingue della Documentazione

- [English](./FIND_SUBNETS_AGGREGATE_Oracle.en.md)
- [Italiano](./FIND_SUBNETS_AGGREGATE_Oracle.it.md)
- [Latina](./FIND_SUBNETS_AGGREGATE_Oracle.la.md)
- [Esperanto](./FIND_SUBNETS_AGGREGATE_Oracle.eo.md)

## Installazione

Per installare questa funzione nel tuo database Oracle, esegui i seguenti comandi SQL in ordine:

1. Per prima cosa, installa le funzioni di supporto se non l'hai già fatto:
[`HELPER_FUNCTIONS_Oracle.sql`](./sql/HELPER_FUNCTIONS_Oracle.sql)

2. Quindi installa la funzione FIND_SUBNETS_AGGREGATE:
[`FIND_SUBNETS_AGGREGATE_Oracle.sql`](./sql/FIND_SUBNETS_AGGREGATE_Oracle.sql)

## Utilizzo

### Sintassi

```sql
SELECT FIND_SUBNETS_AGGREGATE(subnet_list) FROM DUAL;
```

### Parametri

- **subnet_list**: Una lista di specifiche di subnet separate da virgola in notazione CIDR (es., '192.168.1.0/24,192.168.2.0/24')

### Valore di Ritorno

Restituisce una stringa che rappresenta la subnet aggregata minima (in notazione CIDR) che comprende tutte le subnet fornite.

## Esempi

1. Trovare l'aggregato di due subnet /24 adiacenti:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,192.168.1.0/24') AS subnet_aggregata FROM DUAL;
-- Restituisce '192.168.0.0/23'
```

2. Trovare l'aggregato di subnet non adiacenti:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24,192.168.3.0/24') AS subnet_aggregata FROM DUAL;
-- Restituisce '192.168.0.0/22'
```

3. Trovare l'aggregato di subnet con lunghezze CIDR diverse:
```sql
SELECT FIND_SUBNETS_AGGREGATE('10.0.0.0/24,10.0.1.0/24,10.0.2.0/23') AS subnet_aggregata FROM DUAL;
-- Restituisce '10.0.0.0/22'
```

4. Trovare l'aggregato di subnet da spazi di indirizzi diversi:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,10.0.0.0/24') AS subnet_aggregata FROM DUAL;
-- Restituisce '0.0.0.0/0' (l'intero spazio di indirizzi IPv4)
```

5. Trovare l'aggregato di una singola subnet (restituisce la stessa subnet):
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24') AS subnet_aggregata FROM DUAL;
-- Restituisce '192.168.1.0/24'
```

## Come Funziona

La funzione opera in diverse fasi:

1. **Analizza la lista delle subnet**: Utilizza le funzioni REGEXP di Oracle per dividere la lista separata da virgole e contare il numero di subnet.

2. **Trova gli indirizzi IP minimi e massimi**: 
   - Converte ogni subnet nel suo indirizzo di rete e indirizzo di broadcast utilizzando le funzioni di supporto
   - Tiene traccia dell'indirizzo di rete più basso e dell'indirizzo di broadcast più alto

3. **Calcola il prefisso comune**:
   - Partendo dal bit più a sinistra, conta quanti bit sono identici tra l'indirizzo IP minimo e massimo
   - Poiché Oracle non ha operatori di shift di bit diretti come MySQL, utilizza operazioni di divisione e BITAND per controllare ogni bit
   - Questo conteggio diventa la lunghezza del prefisso CIDR per la subnet aggregata

4. **Calcola l'indirizzo di rete**:
   - Applica la maschera derivata dalla lunghezza del prefisso all'indirizzo IP minimo usando BITAND
   - Questo assicura che l'indirizzo di rete sia correttamente allineato al confine CIDR

5. **Genera la notazione CIDR**:
   - Combina l'indirizzo di rete con la lunghezza del prefisso per creare la specifica della subnet aggregata

## Differenze dall'Implementazione MySQL

L'implementazione Oracle differisce dalla versione MySQL in diversi modi:

1. **Manipolazione delle Stringhe**: Oracle usa `REGEXP_SUBSTR` per l'elaborazione delle stringhe invece di `SUBSTRING_INDEX` di MySQL.

2. **Conversione IP**: Oracle richiede funzioni personalizzate `IP_TO_NUM` e `NUM_TO_IP` poiché manca delle funzioni integrate `INET_ATON()` e `INET_NTOA()` di MySQL.

3. **Operazioni Bit a Bit**: Oracle non supporta operatori di shift di bit diretti come `>>` di MySQL. Invece, la funzione utilizza divisione per potenze di 2 insieme a `FLOOR()` e `BITAND()` per simulare le operazioni di shift di bit.

4. **Dichiarazione delle Variabili**: PL/SQL di Oracle richiede che tutte le variabili siano dichiarate all'inizio di un blocco, mentre MySQL consente una maggiore flessibilità nelle dichiarazioni di variabili.

5. **Differenze di Sintassi**: Oracle richiede una barra obliqua (/) dopo le definizioni di funzione e utilizza una sintassi di struttura di loop diversa.

## Note

- La funzione restituisce sempre l'aggregato più piccolo possibile che contiene tutte le subnet di input.
- Quando le subnet sono molto distanti, l'aggregato può includere un numero significativo di indirizzi IP indesiderati.
- Per subnet da blocchi principali diversi (es., 10.x.x.x e 192.168.x.x), l'aggregato sarà molto grande.
- Per identificare le subnet indesiderate incluse nell'aggregato, utilizzare la procedura `LIST_UNWANTED_SUBNETS`.
- Questa funzione è una dipendenza per la funzione `CHECK_SUBNET_RELATIONSHIP` quando si testano le relazioni 'AGGREGABLE'.
