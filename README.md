# Infraestructura de Ruteo Unificado con Traefik y Podman

Este proyecto implementa una arquitectura de **Proxy Inverso** utilizando **Traefik v3** orquestado con **Podman**. Su objetivo es centralizar el acceso a múltiples aplicaciones bajo un único dominio y una estructura de rutas estandarizada (`/laboratorio/`), gestionando tanto contenedores locales como servicios externos.

## 📋 Tabla de Contenidos
1. [Arquitectura y Tecnologías](#-arquitectura-y-tecnologías)
2. [Lógica de Orquestación](#-lógica-de-orquestación-compose-vs-env)
3. [Estructura del Proyecto](#-estructura-del-proyecto)
4. [Instalación y Despliegue](#-instalación-y-despliegue)
5. [Guía de Configuración](#-guía-de-configuración)
6. [Pruebas y Auditoría](#-pruebas-y-auditoría)
7. [Retos Técnicos y Soluciones](#-retos-técnicos-y-soluciones)

---

## 🛠 Arquitectura y Tecnologías

El sistema actúa como una pasarela segura (Gateway) que intercepta el tráfico HTTP/HTTPS y lo distribuye según la ruta solicitada.

* **Orquestador:** Podman & Podman Compose (Modo Rootful para gestión de puertos privilegiados).
* **Reverse Proxy:** Traefik v3.0.
* **Servidores Internos:** Nginx (Alpine Linux).
* **Seguridad:** Terminación SSL/TLS con certificados autofirmados (OpenSSL).
* **Automatización:** Scripting Bash para generación dinámica de configuraciones.

---

## 🧠 Lógica de Orquestación: Compose vs. Env

Para entender cómo administrar este proyecto, es crucial distinguir entre **Orquestar** y **Enrutar**.

| Componente | ¿Dónde se define? | ¿Quién lo administra? | Descripción |
| :--- | :--- | :--- | :--- |
| **Proyectos Locales** | `compose.yaml` | **Podman** | Son aplicaciones que viven dentro del servidor (laptop). Podman debe descargar la imagen, crear el contenedor y encenderlo. Se configuran mediante **Labels** de Docker. |
| **Servicios Externos** | `.env` | **Nadie (Ya existen)** | Son aplicaciones que viven en otros servidores, IPs o la Nube (ej. Google, GeoAsistente). Podman no los controla. Traefik solo necesita saber su IP para redirigir el tráfico. |

> **Analogía:** El `compose.yaml` es el plano de tu edificio (quién trabaja adentro). El `.env` es la agenda telefónica para transferir llamadas a sucursales externas.

---

## 📂 Estructura del Proyecto

```text
.
├── compose.yaml            # Definición de contenedores locales (Traefik, Nginx P1, P2)
├── setup.sh                # Script maestro de inicialización y generación de config
├── test_lab.sh             # Script de auditoría y pruebas automatizadas
├── .env                    # "Fuente de la Verdad" para rutas externas
├── traefik/
│   ├── traefik.yml         # Configuración estática de Traefik
│   └── dynamic_conf.yml    # (Generado automáticamente) Reglas de ruteo externo
├── certs/                  # (Generado automáticamente) Llaves SSL
├── proyecto1/              # Código fuente Proyecto 1
└── proyecto2/              # Código fuente Proyecto 2
