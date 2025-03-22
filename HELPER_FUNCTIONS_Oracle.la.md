# Functiones Auxiliares pro Administratione Subretium IP (Oracle)

Hoc documentum describit functiones auxiliares essentiales requisitas pro operationibus subretium IP in Oracle Database. Hae functiones praebent fundamenta elementa pro operationibus administrationes subretium complexioribus et compensant defectum functionum integratarum pro manipulatione inscriptionum IP in Oracle.

## Linguae Documentationis

- [English](./HELPER_FUNCTIONS_Oracle.en.md)
- [Italiano](./HELPER_FUNCTIONS_Oracle.it.md)
- [Latina](./HELPER_FUNCTIONS_Oracle.la.md)
- [Esperanto](./HELPER_FUNCTIONS_Oracle.eo.md)

## Installatio

Ad has functiones auxiliares in tua base datorum Oracle installandas, exsequere haec mandata SQL:

```sql
-- Converte inscriptionem IP ad numerum
CREATE OR REPLACE FUNCTION IP_TO_NUM(ip_address IN VARCHAR2)
RETURN NUMBER IS
    v_octet1 NUMBER;
    v_octet2 NUMBER;
    v_octet3 NUMBER;
    v_octet4 NUMBER;
BEGIN
    v_octet1 := TO_NUMBER(REGEXP_SUBSTR(ip_address, '[^.]+', 1, 1));
    v_octet2 := TO_NUMBER(REGEXP_SUBSTR(ip_address, '[^.]+', 1, 2));
    v_octet3 := TO_NUMBER(REGEXP_SUBSTR(ip_address, '[^.]+', 1, 3));
    v_octet4 := TO_NUMBER(REGEXP_SUBSTR(ip_address, '[^.]+', 1, 4));
    
    RETURN (v_octet1 * 256 * 256 * 256) + 
           (v_octet2 * 256 * 256) + 
           (v_octet3 * 256) + 
           v_octet4;
END;
/

-- Converte numerum ad inscriptionem IP
CREATE OR REPLACE FUNCTION NUM_TO_IP(ip_num IN NUMBER)
RETURN VARCHAR2 IS
    v_octet1 NUMBER;
    v_octet2 NUMBER;
    v_octet3 NUMBER;
    v_octet4 NUMBER;
BEGIN
    v_octet1 := TRUNC(ip_num / (256 * 256 * 256));
    v_octet2 := TRUNC(MOD(ip_num, 256 * 256 * 256) / (256 * 256));
    v_octet3 := TRUNC(MOD(ip_num, 256 * 256) / 256);
    v_octet4 := MOD(ip_num, 256);
    
    RETURN v_octet1 || '.' || v_octet2 || '.' || v_octet3 || '.' || v_octet4;
END;
/

-- Functio auxiliaris ad obtinendum inscriptionem retis ab IP et CIDR
CREATE OR REPLACE FUNCTION GET_NETWORK_ADDRESS(ip IN VARCHAR2, cidr IN NUMBER)
RETURN VARCHAR2 IS
    ip_num NUMBER;
    mask NUMBER;
BEGIN
    ip_num := IP_TO_NUM(ip);
    mask := POWER(2, 32) - POWER(2, 32 - cidr);
    
    RETURN NUM_TO_IP(BITAND(ip_num, mask));
END;
/

-- Functio auxiliaris ad obtinendum inscriptionem divulgationis ab IP et CIDR
CREATE OR REPLACE FUNCTION GET_BROADCAST_ADDRESS(ip IN VARCHAR2, cidr IN NUMBER)
RETURN VARCHAR2 IS
    ip_num NUMBER;
    mask NUMBER;
    broadcast NUMBER;
BEGIN
    ip_num := IP_TO_NUM(ip);
    mask := POWER(2, 32) - POWER(2, 32 - cidr);
    broadcast := ip_num + POWER(2, 32 - cidr) - 1;
    
    RETURN NUM_TO_IP(broadcast);
END;
/
```

## Descriptiones Functionum

### IP_TO_NUM

Haec functio convertit inscriptionem IPv4 in notatione decimali punctata ad eius repraesentationem numericam.

#### Syntaxis

```sql
IP_TO_NUM(ip_address)
```

#### Parametri

- **ip_address**: Catena repraesentans inscriptionem IPv4 (e.g., '192.168.1.1')

#### Valor Reditus

Reddit NUMBER repraesentantem valorem numericum inscriptionis IP.

#### Quomodo Functio Operatur

Functio:
1. Utitur Oracle's `REGEXP_SUBSTR` ad extrahendum quodque octetum e notatione decimali punctata
2. Convertit quodque octetum ad numerum utens `TO_NUMBER`
3. Calculat repraesentationem numericam finalem multiplicando quodque octetum per potestatem appropriatam numeri 256
4. Reddit summam, quae est repraesentatio numerica inscriptionis IPv4

### NUM_TO_IP

Haec functio convertit repraesentationem numericam inscriptionis IPv4 retro ad notationem decimalem punctatam.

#### Syntaxis

```sql
NUM_TO_IP(ip_num)
```

#### Parametri

- **ip_num**: NUMBER repraesentans valorem numericum inscriptionis IPv4

#### Valor Reditus

Reddit catenam continentem inscriptionem IP in notatione decimali punctata.

#### Quomodo Functio Operatur

Functio:
1. Extrahit quodque octetum exsequendo operationes divisionis et moduli in numero introducto
2. Utitur `TRUNC` ad securandum resultata integra
3. Concatenat octetos cum punctis ad formandam repraesentationem decimalem punctatam

### GET_NETWORK_ADDRESS

Haec functio calculat inscriptionem retis pro data inscriptione IP et longitudine praefixorum CIDR.

#### Syntaxis

```sql
GET_NETWORK_ADDRESS(ip, cidr)
```

#### Parametri

- **ip**: Catena repraesentans inscriptionem IPv4 (e.g., '192.168.1.1')
- **cidr**: Numerus repraesentans longitudinem praefixorum CIDR (0-32)

#### Valor Reditus

Reddit catenam continentem inscriptionem retis in notatione decimali punctata.

#### Quomodo Functio Operatur

Functio:
1. Convertit inscriptionem IP ad valorem numericum utens `IP_TO_NUM`
2. Calculat mascam subretis ex longitudine praefixorum CIDR
3. Applicat operationem ET bit-per-bit utens functione Oracle's `BITAND` inter IP et mascam ad obtinendum inscriptionem retis
4. Convertit resultatum retro ad notationem decimalem punctatam utens `NUM_TO_IP`

### GET_BROADCAST_ADDRESS

Haec functio calculat inscriptionem divulgationis pro data inscriptione IP et longitudine praefixorum CIDR.

#### Syntaxis

```sql
GET_BROADCAST_ADDRESS(ip, cidr)
```

#### Parametri

- **ip**: Catena repraesentans inscriptionem IPv4 (e.g., '192.168.1.1')
- **cidr**: Numerus repraesentans longitudinem praefixorum CIDR (0-32)

#### Valor Reditus

Reddit catenam continentem inscriptionem divulgationis in notatione decimali punctata.

#### Quomodo Functio Operatur

Functio:
1. Convertit inscriptionem IP ad valorem numericum utens `IP_TO_NUM`
2. Calculat mascam subretis ex longitudine praefixorum CIDR
3. Addit numerum hospitum in subrete (2^(32-cidr) - 1) ad inscriptionem retis ad obtinendum inscriptionem divulgationis
4. Convertit resultatum retro ad notationem decimalem punctatam utens `NUM_TO_IP`

## Exempla

### Convertendo Inter Formatos IP

```sql
-- Converte inscriptionem IP ad numerum
SELECT IP_TO_NUM('192.168.1.1') AS ip_num FROM DUAL;
-- Reddit 3232235777

-- Converte numerum retro ad inscriptionem IP
SELECT NUM_TO_IP(3232235777) AS ip_address FROM DUAL;
-- Reddit '192.168.1.1'
```

### Inveniendo Inscriptiones Retis et Divulgationis

```sql
-- Inveni inscriptionem retis pro subrete
SELECT GET_NETWORK_ADDRESS('192.168.1.15', 24) AS inscriptio_retis FROM DUAL;
-- Reddit '192.168.1.0'

-- Inveni inscriptionem divulgationis pro subrete
SELECT GET_BROADCAST_ADDRESS('192.168.1.15', 24) AS inscriptio_divulgationis FROM DUAL;
-- Reddit '192.168.1.255'

-- Inveni ambas pro subrete differenti
SELECT 
    GET_NETWORK_ADDRESS('10.45.67.89', 16) AS inscriptio_retis,
    GET_BROADCAST_ADDRESS('10.45.67.89', 16) AS inscriptio_divulgationis
FROM DUAL;
-- Reddit:
-- inscriptio_retis: '10.45.0.0'
-- inscriptio_divulgationis: '10.45.255.255'
```

### Utendo Functiones in Quaestionibus

```sql
-- Examina si IP est in subrete specifica
WITH test_data AS (
    SELECT '10.20.30.40' AS ip FROM DUAL
)
SELECT 
    ip,
    '10.20.0.0/16' AS subretis,
    CASE 
        WHEN IP_TO_NUM(ip) BETWEEN 
            IP_TO_NUM(GET_NETWORK_ADDRESS('10.20.0.0', 16)) AND 
            IP_TO_NUM(GET_BROADCAST_ADDRESS('10.20.0.0', 16))
        THEN 'ITA'
        ELSE 'NON'
    END AS est_in_subrete
FROM test_data;
-- Reddit 'ITA' indicans IP esse in subrete
```

## Differentiae a MySQL

Hae functiones auxiliares Oracle creatae sunt ad substituendum functiones integratas MySQL pro manipulatione inscriptionum IP:

1. **IP_TO_NUM et NUM_TO_IP**: Substituunt functiones MySQL's `INET_ATON()` et `INET_NTOA()` respective.

2. **Usus Expressionum Regularium**: Oracle utitur `REGEXP_SUBSTR` ad analysandum octetos IP, dum MySQL potest uti `SUBSTRING_INDEX`.

3. **Manipulatio Bitorum**: Oracle utitur `BITAND` pro operationibus ET bit-per-bit, dum MySQL utitur operatore `&`.

4. **Syntaxis Functionis**: Oracle requirit virgulam inclinatam antrorsum (/) post definitionem functionis ad significandum finem corporis functionis.

## Notae

- Hae functiones auxiliares sunt praequisitae necessariae pro aliis functionibus administrationis subretium in Oracle.
- Implementatio currens supportat solum inscriptiones IPv4.
- Oracle tractat inscriptiones IP numericas ut numeros regulares, sic calculationes involventes subretes valde magnas possunt requirere attentionem specialem ad securandam praecisionem numericam.
- In Oracle, functio `IP_TO_NUM` reddit typum datum NUMBER, qui habet praecisionem sufficientem ad tractandum plenum ambitum inscriptionum IPv4 (0 ad 4,294,967,295).
