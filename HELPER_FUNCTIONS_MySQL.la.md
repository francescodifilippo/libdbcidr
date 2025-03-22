# Functiones Auxiliares pro Administratione Subretium IP (MySQL)

Hoc documentum describit functiones auxiliares essentiales requisitas pro operationibus subretium IP in MySQL. Hae functiones praebent fundamenta elementa pro operationibus administrationes subretium complexioribus.

## Linguae Documentationis

- [English](./HELPER_FUNCTIONS_MySQL.en.md)
- [Italiano](./HELPER_FUNCTIONS_MySQL.it.md)
- [Latina](./HELPER_FUNCTIONS_MySQL.la.md)
- [Esperanto](./HELPER_FUNCTIONS_MySQL.eo.md)

## Installatio

Ad has functiones auxiliares in tua base datorum MySQL installandas, exsequere haec mandata SQL:

```sql
-- Functio auxiliaris ad obtinendum inscriptionem retis ab IP et CIDR
CREATE FUNCTION GET_NETWORK_ADDRESS(ip VARCHAR(15), cidr INT)
RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN
    DECLARE ip_num BIGINT;
    DECLARE mask BIGINT;
    
    SET ip_num = INET_ATON(ip);
    SET mask = POWER(2, 32) - POWER(2, 32 - cidr);
    
    RETURN INET_NTOA(ip_num & mask);
END;

-- Functio auxiliaris ad obtinendum inscriptionem divulgationis ab IP et CIDR
CREATE FUNCTION GET_BROADCAST_ADDRESS(ip VARCHAR(15), cidr INT)
RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN
    DECLARE ip_num BIGINT;
    DECLARE mask BIGINT;
    DECLARE broadcast BIGINT;
    
    SET ip_num = INET_ATON(ip);
    SET mask = POWER(2, 32) - POWER(2, 32 - cidr);
    SET broadcast = ip_num | (POWER(2, 32 - cidr) - 1);
    
    RETURN INET_NTOA(broadcast);
END;
```

## Descriptiones Functionum

### GET_NETWORK_ADDRESS

Haec functio calculat inscriptionem retis pro data inscriptione IP et longitudine praefixorum CIDR.

#### Syntaxis

```sql
GET_NETWORK_ADDRESS(ip, cidr)
```

#### Parametri

- **ip**: Catena repraesentans inscriptionem IPv4 (e.g., '192.168.1.1')
- **cidr**: Integer repraesentans longitudinem praefixorum CIDR (0-32)

#### Valor Reditus

Reddit catenam continentem inscriptionem retis in notatione decimali punctata.

#### Quomodo Functio Operatur

Functio:
1. Convertit inscriptionem IP ad valorem numericum utens functione MySQL's `INET_ATON()`
2. Calculat mascam subretis ex longitudine praefixorum CIDR
3. Applicat operationem ET bit-per-bit inter IP et mascam ad obtinendum inscriptionem retis
4. Convertit resultatum ad notationem decimalem punctatam utens `INET_NTOA()`

### GET_BROADCAST_ADDRESS

Haec functio calculat inscriptionem divulgationis pro data inscriptione IP et longitudine praefixorum CIDR.

#### Syntaxis

```sql
GET_BROADCAST_ADDRESS(ip, cidr)
```

#### Parametri

- **ip**: Catena repraesentans inscriptionem IPv4 (e.g., '192.168.1.1')
- **cidr**: Integer repraesentans longitudinem praefixorum CIDR (0-32)

#### Valor Reditus

Reddit catenam continentem inscriptionem divulgationis in notatione decimali punctata.

#### Quomodo Functio Operatur

Functio:
1. Convertit inscriptionem IP ad valorem numericum utens functione MySQL's `INET_ATON()`
2. Calculat mascam subretis ex longitudine praefixorum CIDR
3. Applicat operationem VEL bit-per-bit inter IP et inversam mascam ad obtinendum inscriptionem divulgationis
4. Convertit resultatum ad notationem decimalem punctatam utens `INET_NTOA()`

## Exempla

### Inveniendo Inscriptionem Retis

```sql
SELECT GET_NETWORK_ADDRESS('192.168.1.15', 24);
-- Reddit '192.168.1.0'

SELECT GET_NETWORK_ADDRESS('10.45.67.89', 16);
-- Reddit '10.45.0.0'

SELECT GET_NETWORK_ADDRESS('172.16.28.30', 20);
-- Reddit '172.16.16.0'
```

### Inveniendo Inscriptionem Divulgationis

```sql
SELECT GET_BROADCAST_ADDRESS('192.168.1.15', 24);
-- Reddit '192.168.1.255'

SELECT GET_BROADCAST_ADDRESS('10.45.67.89', 16);
-- Reddit '10.45.255.255'

SELECT GET_BROADCAST_ADDRESS('172.16.28.30', 20);
-- Reddit '172.16.31.255'
```

### Utendo Ambas Functiones Simul

```sql
-- Inveni et inscriptionem retis et inscriptionem divulgationis pro subrete
SELECT 
    GET_NETWORK_ADDRESS('192.168.5.37', 22) AS inscriptio_retis,
    GET_BROADCAST_ADDRESS('192.168.5.37', 22) AS inscriptio_divulgationis;
-- Reddit:
-- inscriptio_retis: '192.168.4.0'
-- inscriptio_divulgationis: '192.168.7.255'

-- Verifica si IP est in subrete specifica
SELECT 
    '10.20.30.40' AS ip,
    '10.20.0.0/16' AS subretis,
    (INET_ATON('10.20.30.40') BETWEEN 
     INET_ATON(GET_NETWORK_ADDRESS('10.20.0.0', 16)) AND 
     INET_ATON(GET_BROADCAST_ADDRESS('10.20.0.0', 16))) AS est_in_subrete;
-- Reddit 1 (VERUM) indicans IP esse in subrete
```

## Notae

- Hae functiones dependent in functionibus integratis MySQL's `INET_ATON()` et `INET_NTOA()`, quae disponibiles sunt in MySQL 5.6.3 et posterioribus.
- Functiones habent attributum `DETERMINISTIC`, quod adiuvat ad optimizationem quaestionum.
- Hae functiones auxiliares sunt praequisitae necessariae pro aliis functionibus administrationis subretium:
  - `CHECK_SUBNET_RELATIONSHIP`
  - `FIND_SUBNETS_AGGREGATE`
  - `LIST_UNWANTED_SUBNETS`
- Implementatio currens supportat solum inscriptiones IPv4.
