# Funzione FIND_SUBNETS_AGGREGATE (MySQL)

Questa funzione calcola la subnet aggregata minima che comprende tutte le subnet IP fornite.

## Lingue della Documentazione

- [English](./FIND_SUBNETS_AGGREGATE_MySQL.en.md)
- [Italiano](./FIND_SUBNETS_AGGREGATE_MySQL.it.md)
- [Latina](./FIND_SUBNETS_AGGREGATE_MySQL.la.md)
- [Esperanto](./FIND_SUBNETS_AGGREGATE_MySQL.eo.md)

## Installazione

Per installare questa funzione nel tuo database MySQL, esegui i seguenti comandi SQL in ordine:

1. Prima, installa le funzioni di supporto se non l'hai già fatto:
[`HELPER_FUNCTIONS_MySQL.sql`](./sql/HELPER_FUNCTIONS_MySQL.sql)

2. Quindi installa la funzione FIND_SUBNETS_AGGREGATE:
[`FIND_SUBNETS_AGGREGATE_MySQL.sql`](./sql/FIND_SUBNETS_AGGREGATE_MySQL.sql)

## Utilizzo

### Sintassi

```sql
SELECT FIND_SUBNETS_AGGREGATE(subnet_list);
```

### Parametri

- **subnet_list**: Una lista di specifiche di subnet separate da virgola in notazione CIDR (es., '192.168.1.0/24,192.168.2.0/24')

### Valore di Ritorno

Restituisce una stringa che rappresenta la subnet aggregata minima (in notazione CIDR) che comprende tutte le subnet fornite.

## Esempi

1. Trova l'aggregato di due subnet /24 adiacenti:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,192.168.1.0/24');
-- Restituisce '192.168.0.0/23'
```

2. Trova l'aggregato di subnet non adiacenti:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24,192.168.3.0/24');
-- Restituisce '192.168.0.0/22'
```

3. Trova l'aggregato di subnet con lunghezze CIDR diverse:
```sql
SELECT FIND_SUBNETS_AGGREGATE('10.0.0.0/24,10.0.1.0/24,10.0.2.0/23');
-- Restituisce '10.0.0.0/22'
```

4. Trova l'aggregato di subnet da spazi di indirizzi diversi:
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.0.0/24,10.0.0.0/24');
-- Restituisce '0.0.0.0/0' (l'intero spazio di indirizzi IPv4)
```

5. Trova l'aggregato di una singola subnet (restituisce la stessa subnet):
```sql
SELECT FIND_SUBNETS_AGGREGATE('192.168.1.0/24');
-- Restituisce '192.168.1.0/24'
```

## Come Funziona

La funzione opera in diverse fasi:

1. **Analisi della lista di subnet**: Divide la lista separata da virgole e conta il numero di subnet.

2. **Trova gli indirizzi IP minimi e massimi**: 
   - Converte ciascuna subnet nel suo indirizzo di rete e indirizzo di broadcast
   - Tiene traccia dell'indirizzo di rete più basso e dell'indirizzo di broadcast più alto

3. **Calcola il prefisso comune**:
   - Partendo dal bit più a sinistra, conta quanti bit sono identici tra l'indirizzo IP minimo e massimo
   - Questo conteggio diventa la lunghezza del prefisso CIDR per la subnet aggregata

4. **Calcola l'indirizzo di rete**:
   - Applica la maschera derivata dalla lunghezza del prefisso all'indirizzo IP minimo
   - Questo assicura che l'indirizzo di rete sia correttamente allineato al confine CIDR

5. **Genera la notazione CIDR**:
   - Combina l'indirizzo di rete con la lunghezza del prefisso per creare la specifica della subnet aggregata

## Note

- La funzione restituisce sempre l'aggregato più piccolo possibile che contiene tutte le subnet di input.
- Quando le subnet sono molto distanti, l'aggregato può includere un numero significativo di indirizzi IP indesiderati.
- Per subnet da blocchi principali diversi (es., 10.x.x.x e 192.168.x.x), l'aggregato sarà molto grande.
- Per identificare le subnet indesiderate incluse nell'aggregato, usa la procedura `LIST_UNWANTED_SUBNETS`.
