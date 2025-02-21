# Astroport.ONE : Tu Portal Descentralizado hacia una Nueva Frontera Digital

[EN](README.md) - [FR](README.fr.md)


**¡Bienvenido a Astroport.ONE!** Imagina un mundo digital donde tienes el control, donde los datos están seguros, los pagos son fluidos y la comunidad prospera más allá de las fronteras. Astroport.ONE está construyendo este futuro, y estás invitado a formar parte de él.

**¿Qué es Astroport.ONE?**

Astroport.ONE es una plataforma revolucionaria diseñada para empoderar a individuos y comunidades en la era de la Web3. Es más que un simple software; es una caja de herramientas para crear tu propia embajada digital descentralizada - una **Estación** - donde puedes gestionar tu identidad digital, participar en una economía descentralizada utilizando la criptomoneda Ğ1 (June), y contribuir a una red global de estaciones interconectadas.

**Piensa en Astroport.ONE como:**

*   **Tu Refugio de Datos Personal:** Almacena y gestiona tus datos de forma segura gracias al Sistema de Archivos Interplanetario (IPFS), garantizando que sean resistentes a la censura y que estén siempre accesibles.
*   **Un Sistema de Pago Sin Comisiones:** Utiliza la criptomoneda Ğ1 (June) para transacciones entre pares sin intermediarios ni comisiones, fomentando una economía justa y equitativa.
*   **Un Constructor de Comunidad Digital:** Conéctate con otras Estaciones Astroport.ONE y usuarios en todo el mundo, compartiendo información, recursos y construyendo redes basadas en la confianza.
*   **Una "Guía de Construcción" para la Web Descentralizada:** Aprovecha nuestras herramientas y software de código abierto para crear e implementar tus propias aplicaciones y servicios Web3.

## Funcionalidades Esenciales: El Poder de Astroport.ONE

*   **ZenCard y AstroID: Tus Claves de Acceso**

    *   **ZenCard**: Un sistema de pago innovador basado en la simplicidad y seguridad de los códigos QR.
    *   **AstroID**: Tu identidad digital, inviolable y bajo tu control total.

*   **Almacenamiento Descentralizado y Organizado**

    *   **IPFS en el Corazón**: Benefíciate de un almacenamiento distribuido, resistente a la censura y a los fallos centralizados.
    *   **MBR y Tabla de Asignación**: Una organización de datos Tiddlywiki optimizada para el rendimiento y la fiabilidad.

*   **Votos: Las Palabras Clave que Animan a AstroBot**

    *   **Sistema de Votos**: Más que simples deseos, los "Votos" son palabras clave que *tú* defines en tu TiddlyWiki para activar **AstroBot**, el corazón automatizado de Astroport.ONE. Estas palabras clave activan programas en BASH, contratos inteligentes rudimentarios, que te permiten automatizar acciones, sincronizar datos o realizar tareas específicas dentro de tu estación. Si bien los Votos pueden ser respaldados por donaciones en la moneda libre Ğ1, su función principal es orquestar la automatización a través de AstroBOT, y no la financiación colaborativa.

*   **Sincronización y Comunicación P2P**

    *   **Estaciones Astroport.ONE**: Tu estación se comunica y se sincroniza con una red de embajadas digitales, asegurando una consistencia y disponibilidad máximas de los datos.
    *   **AstroBot: Inteligencia al Servicio de Tus Datos**: Un sistema de contratos inteligentes en BASH, que reacciona a los eventos de la red Ğ1 y a los "Votos" para automatizar y optimizar tu experiencia.
    *   **G1PalPay.sh: El Monitor de Transacciones Ğ1**: Un script crucial que monitoriza en tiempo real la blockchain Ğ1. Permite a Astroport.ONE reaccionar a las transacciones, ejecutar comandos basados en los comentarios de las transacciones y gestionar los flujos financieros dentro del ecosistema.

## **¿A Quién se Dirige Astroport.ONE?**

*   **A individuos que buscan la soberanía digital:** Retoma el control de tus datos y de tu presencia en línea.
*   **A comunidades que construyen soluciones descentralizadas:** Crea y gestiona recursos compartidos y proyectos colaborativos.
*   **A desarrolladores e innovadores:** Explora el potencial de la Web3 y construye aplicaciones descentralizadas en una plataforma robusta.
*   **A usuarios de la criptomoneda Ğ1 (June):** Mejora tu experiencia Ğ1 con pagos seguros y un ecosistema floreciente.
*   **A cualquier persona interesada en un mundo digital más libre, más seguro y más interconectado.**

## **Comienza con Astroport.ONE:**

**Instalación (Linux - Debian/Ubuntu/Mint):**

Configurar tu Estación Astroport.ONE es fácil gracias a nuestro script de instalación automatizado:

```bash
bash <(curl -sL https://install.astroport.com)
```

### Procesos en Ejecución

Después de la instalación, deberías encontrar los siguientes procesos en ejecución:

```
/usr/local/bin/ipfs daemon --enable-pubsub-experiment --enable-namesys-pubsub
/bin/bash /home/fred/.zen/G1BILLET/G1BILLETS.sh daemon
/bin/bash /home/fred/.zen/Astroport.ONE/12345.sh
/bin/bash /home/fred/.zen/Astroport.ONE/_12345.sh
```

## Uso

### Creación de un Jugador

Para crear un jugador, define los siguientes parámetros: email, salt, pepper, lat, lon y PASS.

```bash
~/.zen/Astroport.ONE/command.sh
```

### API BASH

Una vez que tu estación Astroport esté iniciada, los siguientes puertos están activados:

- **Puerto 1234**: Publica la API v1 (/45780, /45781 y /45782 son los puertos de respuesta)
- **Puerto 12345**: Publica el mapa de estaciones.
- **Puerto 33101**: Ordena la creación de G1BILLETS (:33102 permite su recuperación)
- **Puertos 8080, 4001 y 5001**: Puertos de la pasarela IPFS.
- **Puerto 54321**: Publica la API v2 ([UPassport](https://github.com/papiche/UPassport/)).

### Ejemplos de Uso de la API

#### Crear un Jugador

```http
GET /?salt=${SALT}&pepper=${PEPPER}&g1pub=${URLENCODEDURL}&email=${PLAYER}
```

#### Leer la Mensajería de la Base de Datos GChange

```http
GET /?salt=${SALT}&pepper=${PEPPER}&messaging=on
```

#### Desencadenar un Pago de Ğ1

```http
GET /?salt=${SALT}&pepper=${PEPPER}&pay=1&g1pub=DsEx1pS33vzYZg4MroyBV9hCw98j1gtHEhwiZ5tK7ech
```

### Uso de la API UPLANET

La API `UPLANET.sh` está dedicada a las aplicaciones OSM2IPFS y UPlanet Client App. Gestiona los aterrizajes UPLANET y la creación de ZenCards y AstroIDs.

#### Parámetros Requeridos

- `uplanet`: Email del jugador.
- `zlat`: Latitud con 2 decimales.
- `zlon`: Longitud con 2 decimales.
- `g1pub`: (Opcional) Idioma de origen (fr, en, ...)

#### Ejemplo de Solicitud

```http
GET /?uplanet=player@example.com&zlat=48.85&zlon=2.35&g1pub=fr
```

| Parámetro | Tipo      | Descripción                         |
| :-------- | :-------- | :---------------------------------- |
| `uplanet` | `email`   | **Requerido**. Email del jugador       |
| `zlat`    | `decimal` | **Requerido**. Latitud con 2 decimales |
| `zlon`    | `decimal` | **Requerido**. Longitud con 2 decimales |
| `g1pub`   | `string`  | **Opcional**. Idioma de origen (fr, en, ...) |

## DOCUMENTACIÓN

https://astroport-1.gitbook.io/astroport.one/

## Contribución

Este proyecto es [una selección](https://github.com/papiche/Astroport.solo) de algunos de los softwares libres y de código abierto más valiosos.

Las contribuciones son bienvenidas en [opencollective.com/monnaie-libre](https://opencollective.com/monnaie-libre#category-BUDGET).

## Observadores a lo largo del tiempo

[![Observadores a lo largo del tiempo](https://starchart.cc/papiche/Astroport.ONE.svg)](https://starchart.cc/papiche/Astroport.ONE)

## Créditos

Gracias a todos los que han contribuido a hacer que este software esté disponible para todos. ¿Conoces [Ğ1](https://monnaie-libre.fr)?

La mejor criptomoneda que puedas soñar.
