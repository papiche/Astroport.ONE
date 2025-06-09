# Astroport.ONE : Tu Puerta Personal al Ecosistema UPlanet

[EN](README.md) - [FR](README.fr.md)

**¡Bienvenido a Astroport.ONE!** Ingresa a un ecosistema digital revolucionario donde controlas tus datos, donde los pagos fluyen transparentemente a través de redes descentralizadas, y donde las comunidades prosperan en armonía con los ritmos solares naturales. Astroport.ONE no es solo software—es tu **♥️BOX** (Corazónbox) personal, una embajada digital completa que alimenta la civilización descentralizada UPlanet.

## 🌍 **¿Qué es UPlanet & Astroport.ONE?**

**UPlanet** es una civilización descentralizada sincronizada con los ritmos naturales de la Tierra, donde cada nodo opera en armonía con el tiempo solar. **Astroport.ONE** es tu puerta personal—una **Estación** completa que sirve como:

*   **🏰 Tu Embajada Digital**: Un nodo soberano en la red UPlanet con tu propio dominio y servicios
*   **🔐 Sistema de Identidad Resistente Cuántico**: Basado en criptografía SSH/GPG con seguridad Nivel-Y y Nivel-Z
*   **💰 Economía Sin Comisiones**: Integración nativa de la criptomoneda Ğ1 (June) con flujos de pagos automatizados
*   **🌐 Malla de Servicios P2P**: Comparte y accede a recursos IA, almacenamiento y computación vía Dragon WOT (Web of Trust)
*   **⏰ Sincronización Tiempo Solar**: Todas las actividades de mantenimiento y red sincronizadas al tiempo solar natural 20h12

## ✨ **Características Revolucionarias**

### **🎯 ZenCard & AstroID: Tus Llaves Universales**
- **ZenCard**: Sistema de pago basado en códigos QR integrando la criptomoneda Ğ1
- **AstroID**: Tu identidad criptográfica, resistente cuántica y completamente bajo tu control
- **UPassport**: Sistema de verificación de identidad inter-plataformas

### **🗃️ Soberanía de Datos Descentralizada**
- **Almacenamiento IPFS Central**: Sistema de archivos distribuido resistente a la censura
- **Organización TiddlyWiki**: Base de conocimientos personal con tablas de asignación MBR
- **Cache FlashMem**: Llaves geográficas (GEOKEYS) para distribución de datos espaciales
- **Inteligencia Swarm**: Protocolos de descubrimiento de nodos y compartición de servicios

### **🤖 Sistema AstroBot & Votos**
- **Palabras Clave Votos**: Define palabras clave personalizadas en tu TiddlyWiki para activar smart contracts BASH automatizados
- **Inteligencia AstroBot**: Responde a eventos blockchain y Votos para automatizar tu vida digital
- **G1PalPay.sh**: Monitor blockchain Ğ1 en tiempo real ejecutando comandos desde comentarios de transacciones

### **🔗 Dragon WOT: Red de Servicios Descentralizada**
El **Dragon Web of Trust** permite túneles P2P seguros de servicios vía IPFS:

- **Acceso SSH**: Acceso shell seguro vía túneles `/x/ssh-{NodeID}`
- **Servicios IA**: Compartición de modelos IA Ollama, ComfyUI, Perplexica
- **Síntesis de Voz**: Compartición del servicio TTS Orpheus
- **Nodos Nivel-Y**: Verificación de llaves SSH por prueba criptográfica
- **Seguridad Nivel-Z**: Autenticación basada GPG para confianza reforzada

### **⏰ Sincronización Tiempo Solar**
Cada nodo UPlanet funciona en **tiempo solar** para armonía natural:
- **Calibración GPS Automática**: Tu posición geográfica determina tu 20h12 solar
- **cron_VRFY.sh**: Calcula el tiempo solar local vía coordenadas GPS
- **solar_time.sh**: Corrección ecuación del tiempo para alineación solar precisa
- **Sincronización Global**: Todos los nodos ejecutan mantenimiento en el mismo momento solar mundial

### **♥️BOX Análisis del Sistema**
Tu estación Astroport.ONE monitorea continuamente:
- **Recursos Hardware**: Utilización CPU, GPU, RAM
- **Capacidad Almacenamiento**: Cálculo automático de slots ZenCard (128GB) y NOSTR Card (10GB)
- **Salud IPFS**: Proximidad garbage collection, conectividad peers
- **Integración NextCloud**: Almacenamiento nube personal con monitoreo de puertos (8001/8002)
- **Sistemas Cache**: Descubrimiento Swarm, perfiles Coucou, geokeys FlashMem

## 🚀 **Instalación & Configuración**

**Instalación Automatizada (Linux - Debian/Ubuntu/Mint):**

```bash
bash <(curl -sL https://install.astroport.com)
```

### **Configuración Inicial del Capitán**
Tu primera cuenta se convierte en el **Capitán** de tu ♥️BOX:
- **Recolección GPS**: Tu ubicación se recolecta automáticamente para calibración tiempo solar
- **Verificación Nivel-Y**: Llaves SSH verificadas vía transformación criptográfica
- **Perfil NOSTR**: Creación automática del perfil capitán en redes sociales descentralizadas
- **Dragon WOT**: Integración en el Web of Trust para compartición de servicios P2P

### **Procesos en Funcionamiento**
Después de la instalación, los servicios esenciales incluyen:
```bash
/usr/local/bin/ipfs daemon --enable-pubsub-experiment --enable-namesys-pubsub
/bin/bash ~/.zen/G1BILLET/G1BILLETS.sh daemon
/bin/bash ~/.zen/Astroport.ONE/12345.sh
/bin/bash ~/.zen/Astroport.ONE/_12345.sh
```

## 🔧 **API & Integración**

### **APIs Centrales**
- **Puerto 1234**: API Estación v1 (respuestas: 45780, 45781, 45782)
- **Puerto 12345**: Mapa red estaciones y descubrimiento nodos
- **Puerto 33101**: Creación G1BILLET (:33102 para recuperación)
- **Puerto 54321**: API UPassport v2 para gestión identidad
- **Puertos IPFS**: 8080 (pasarela), 4001 (swarm), 5001 (API)

### **API Geoespacial UPlanet**
Dedicada a aplicaciones OSM2IPFS y clientes UPlanet:

```http
GET /?uplanet=capitan@dominio.com&zlat=48.85&zlon=2.35&g1pub=es
```

| Parámetro | Tipo      | Descripción                                    |
|-----------|-----------|------------------------------------------------|
| `uplanet` | `email`   | **Requerido**. Email del jugador               |
| `zlat`    | `decimal` | **Requerido**. Latitud (precisión 2 decimales)|
| `zlon`    | `decimal` | **Requerido**. Longitud (precisión 2 decimales)|
| `g1pub`   | `string`  | **Opcional**. Código idioma/origen            |

### **API Red Swarm**
- **Descubrimiento Nodos**: Detección automática de servicios en tu swarm
- **Integración Pagos**: PAF (Participation Aux Frais) para suscripciones inter-nodos
- **Túneles de Servicios**: Acceso a recursos IA, almacenamiento y computación remotos

## 🎯 **¿A Quién se Dirige Astroport.ONE?**

*   **🏛️ Soberanos Digitales**: Individuos que buscan control completo sobre su existencia digital
*   **🤝 Comunidades Descentralizadas**: Grupos construyendo sociedades digitales cooperativas
*   **🧠 Desarrolladores IA**: Acceso a compartición distribuida de modelos IA y recursos de computación
*   **💱 Ecosistema Ğ1**: Integración nativa con la moneda libre June/Ğ1
*   **🌱 Entusiastas Ritmos Solares**: Aquellos que buscan armonía con ciclos temporales naturales
*   **🔬 Pioneros Web3**: Desarrolladores construyendo la próxima generación de aplicaciones descentralizadas

## 🏗️ **Características Avanzadas**

### **Economía Inter-Nodos**
- **Suscripciones ZenCard**: Slots de almacenamiento 128GB para usuarios premium
- **NOSTR Cards**: Integración ligera redes sociales 10GB
- **Reservas Capitán**: Reservación automática 8 slots para operadores nodos
- **Pagos Automatizados**: Procesamiento PAF diario para compartición recursos transparente

### **Integración Servicios IA**
- **Ollama**: Despliegue y compartición LLM locales
- **ComfyUI**: Flujos de trabajo avanzados generación de imágenes
- **Perplexica**: Búsqueda web mejorada con asistencia IA
- **Orpheus TTS**: Compartición servicio síntesis de voz

### **Distribución Geográfica**
- **GEOKEYS**: Llaves de datos espaciales para distribución contenido geográfico
- **Integración UMAP**: Integración datos OpenStreetMap
- **Gestión Sectores**: Organización y cache de datos regionales
- **Mapeo TiddlyWiki**: Bases conocimientos personales con contexto geográfico

## 📚 **Documentación & Comunidad**

**Documentación Completa**: https://astroport-1.gitbook.io/astroport.one/

**Contribución**: Este proyecto combina el software libre y código abierto más valioso. Contribuciones bienvenidas en [opencollective.com/monnaie-libre](https://opencollective.com/monnaie-libre#category-BUDGET).

## 🌟 **Observadores en el tiempo**

[![Observadores en el tiempo](https://starchart.cc/papiche/Astroport.ONE.svg)](https://starchart.cc/papiche/Astroport.ONE)

## 🙏 **Créditos**

Gracias a todos los que han contribuido a hacer este software accesible para todos.

**Descubre [Ğ1](https://monnaie-libre.fr)** - La mejor criptomoneda que puedas soñar: libre, descentralizada, y diseñada para renta básica universal a través de la armonía económica natural.
