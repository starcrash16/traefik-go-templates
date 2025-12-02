# Infraestructura de Ruteo Unificado con Traefik y Podman

Este proyecto implementa una arquitectura de **Proxy Inverso** utilizando **Traefik v3** orquestado con **Podman**. Su objetivo es centralizar el acceso a múltiples aplicaciones bajo un único dominio y una estructura de rutas estandarizada (`/laboratorio/`), gestionando tanto contenedores locales como servicios externos.

---

## ¿Cómo funciona la generación automática de nombres?

El script `setup.sh` utiliza una convención de nombres estricta para transformar las variables del archivo `.env` en rutas URL accesibles. El proceso de transformación (parsing) sigue estas 3 reglas lógicas:

1. **Filtro:** El script solo lee las variables que comienzan con el prefijo `APP_`. Cualquier otra variable (como contraseñas o config de BD) es ignorada por seguridad.
2. **Limpieza:** Se elimina el prefijo `APP_` del nombre de la variable.
3. **Normalización:** El texto restante se convierte a minúsculas para cumplir con los estándares de URLs.

---

### Tabla de Transformación (ejemplos)

| Variable en `.env` | Paso 1: Limpieza (sin `APP_`) | Paso 2: Minúsculas | Ruta Resultante |
|---|---|---:|---|
| `APP_NOMINA=...` | `NOMINA` | `nomina` | `nomina/laboratorio/nomina` |
| `APP_RECURSOS_HUMANOS=...` | `RECURSOS_HUMANOS` | `recursos_humanos` | `recursos_humanos/laboratorio/recursos_humanos` |
| `DB_PASSWORD=...` | (Ignorado — no tiene `APP_`) | (Ignorado) | — |

> Nota: la ruta resultante puede adaptarse a la estructura que prefieras (por ejemplo `/laboratorio/<nombre>`). El ejemplo anterior sigue la convención interna usada por `setup.sh` en este proyecto.

## Tabla de Contenidos
1. [Arquitectura y Tecnologías](#-arquitectura-y-tecnologías)
2. [Lógica de Orquestación](#-lógica-de-orquestación-compose-vs-env)
3. [Estructura del Proyecto](#-estructura-del-proyecto)
4. [Instalación y Despliegue](#-instalación-y-despliegue)
5. [Guía de Configuración](#-guía-de-configuración)
6. [Pruebas y Auditoría](#-pruebas-y-auditoría)
7. [Retos Técnicos y Soluciones](#-retos-técnicos-y-soluciones)

---

## Arquitectura y Tecnologías

El sistema actúa como una pasarela segura (Gateway) que intercepta el tráfico HTTP/HTTPS y lo distribuye según la ruta solicitada.

* **Orquestador:** Podman & Podman Compose (Modo Rootful para gestión de puertos privilegiados).
* **Reverse Proxy:** Traefik v3.0.
* **Servidores Internos:** Nginx (Alpine Linux).
* **Seguridad:** Terminación SSL/TLS con certificados autofirmados (OpenSSL).
* **Automatización:** Scripting Bash para generación dinámica de configuraciones.

---

## Lógica de Orquestación: Compose vs. Env

Para entender cómo administrar este proyecto, es crucial distinguir entre **Orquestar** y **Enrutar**.

| Componente | ¿Dónde se define? | ¿Quién lo administra? | Descripción |
| :--- | :--- | :--- | :--- |
| **Proyectos Locales** | `compose.yaml` | **Podman** | Son aplicaciones que viven dentro del servidor (laptop). Podman debe descargar la imagen, crear el contenedor y encenderlo. Se configuran mediante **Labels** de Docker. |
| **Servicios Externos** | `.env` | **Nadie (Ya existen)** | Son aplicaciones que viven en otros servidores, IPs o la Nube (ej. Google, GeoAsistente). Podman no los controla. Traefik solo necesita saber su IP para redirigir el tráfico. |

> **Analogía:** El `compose.yaml` es el plano de tu edificio (quién trabaja adentro). El `.env` es la agenda telefónica para transferir llamadas a sucursales externas.

---

## Estructura del Proyecto

```text
.
├── compose.yaml            # Definición de contenedores locales (Traefik, Nginx P1, P2)
├── setup.sh                # Script maestro de inicialización y generación de config
├── test_lab.sh             # Script de auditoría y pruebas automatizadas
├── .env                    # Fuente para rutas externas
├── traefik/
│   ├── traefik.yml         # Configuración estática de Traefik
│   └── dynamic_conf.yml    # (Generado automáticamente) Reglas de ruteo externo
├── certs/                  # (Generado automáticamente) Llaves SSL
├── proyecto1/              # Código fuente Proyecto 1
└── proyecto2/              # Código fuente Proyecto 2
```
---

# Instalación y Despliegue

## Requisitos
- Linux (o WSL2) con **Podman** instalado.  
- **Root (sudo)** es requerido para vincular los puertos **80** y **443**.

## Pasos
### 1. Clonar el repositorio:
```bash
git clone <URL_DEL_REPOSITORIO>
cd nombre-repo
```

### 2. Inicializar el entorno:
Ejecute el script de configuración. Esto generará los certificados SSL y convertirá el archivo .env en una configuración válida para Traefik.
```bash
chmod +x setup.sh
./setup.sh
```

### 3. Levantar la infraestructura:
```bash
sudo podman-compose up -d
```

### 4. Verificar estado:
```bash
sudo podman ps
# Deben aparecer: traefik-proxy, nginx-p1, nginx-p2 en estado "Up".
```

---

# Guía de Configuración

## Caso A: Agregar un nuevo Proyecto Local

1. Edite `compose.yaml`.
2. Agregue el servicio y defina las etiquetas (labels) para Traefik:
   - Añada las labels de routing.
   - Ajuste el puerto del servicio.


```bash
labels:
  - "traefik.http.routers.mi-app.rule=PathPrefix(`/laboratorio/mi-app`)"
  - "traefik.http.services.mi-app.loadbalancer.server.port=80"
```
3. Reinicie: podman-compose up -d.

## Caso B: Agregar una Ruta a un Servidor Externo (IP)
1. Edite el archivo .env:
```bash
APP_NUEVO_SISTEMA=[http://192.168.1.50:3000](http://192.168.1.50:3000)
```
2. Regenere la configuración:
```bash
./setup.sh
```
(No requiere reiniciar contenedores, Traefik detecta el cambio en caliente).

---

# Pruebas y Auditoría
Se incluye un script automatizado para validar la salud del sistema.

```bash
chmod +x test_lab.sh
./test_lab.sh
```
**Interpretación de Resultados Manuales (curl)**

| Ruta | Resultado Típico | Interpretación |
| :--- | :--- | :--- |
| `/laboratorio/proyecto1/` | **200 OK** | El contenedor local responde correctamente. |
| `/laboratorio/google/` | **200 / 404** | Éxito. Traefik logró salir a Internet. |
| `/laboratorio/geoasistente/` | **502 / 504** | Éxito (en red externa). Traefik creó la ruta e intentó conectar, pero la IP privada no es alcanzable desde la ubicación actual. |


---
# Retos Técnicos y Soluciones
### 1. Incompatibilidad de Redes CNI (Version Mismatch)
* **Problema:** `podman-compose` generaba configuraciones de red versión `1.0.0`, incompatibles con los plugins CNI del sistema (`0.4.0`), impidiendo el arranque de contenedores.
* **Solución:** Implementación de parches manuales sobre `/etc/cni/net.d/` y recreación controlada de la red `podman` por defecto.

### 2. Gestión de Permisos (Root vs Rootless)
* **Problema:** La ejecución como usuario estándar impedía el uso de puertos privilegiados (80/443) y causaba conflictos con la ubicación del socket de Podman (`/run/user/1000` vs `/run/podman`).
* **Solución:** Estandarización del despliegue en modo **Root**, ajustando el volumen del socket en `compose.yaml` para apuntar a la ruta del sistema.

### 3. Generación Dinámica de Configuración (Go Templates vs Bash)
* **Problema:** El *File Provider* de la versión actual de Traefik presentó inestabilidad al procesar plantillas Go (`{{ range }}`) en tiempo de ejecución (*runtime*), arrojando errores de `field not found`.
* **Solución:** Se trasladó la lógica de templating a una fase de **pre-compilación** usando Bash (`setup.sh`). Esto garantiza que Traefik siempre reciba un archivo YAML estático y válido, eliminando la fragilidad en producción y facilitando la auditoría de la configuración generada.

### 4. Race Condition en Volúmenes
* **Problema:** Al iniciar el orquestador antes de la existencia de los archivos de configuración, Podman creaba directorios en lugar de archivos, causando el error `is a directory` en Traefik.
* **Solución:** Implementación estricta del script de inicialización (`setup.sh`) como prerrequisito de despliegue.








