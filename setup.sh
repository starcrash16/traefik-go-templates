# --- CONFIGURACIÓN DEL PROYECTO ---
#!/bin/bash

# --- CONFIGURACIÓN ---
DOMINIO="cienciadedatos.inegi.org.mx"

echo "Iniciando configuración del Laboratorio /INEGI..."

# 1. Crear estructura de carpetas
echo "Creando directorios..."
mkdir -p certs
mkdir -p traefik
mkdir -p proyecto1
mkdir -p proyecto2

# 2. Generar archivo .env (Si no existe)
# Vital para que funcionamiento de dynamic_conf.yml con Go Templates
if [ ! -f .env ]; then
    echo "Creando archivo .env base..."
    cat <<EOF > .env
# --- RUTAS EXTERNAS PARA TRAEFIK (Dynamic Conf) ---
# Formato: APP_NOMBRE=URL_DESTINO
# Se crearán en: /laboratorio/nombre

# Ejemplo: GeoAsistente (Servidor LAN)
APP_GEOASISTENTE=http://10.152.11.81:8010

# Puedes agregar más aquí abajo:

EOF
    echo " Archivo .env creado."
else
    echo " El archivo .env ya existe."
fi

# 3. Generar Certificados SSL
if [ ! -f certs/local.key ]; then
   echo "Generando certificados SSL para $DOMINIO..."
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -keyout certs/local.key \
        -out certs/local.crt \
        -subj "/CN=$DOMINIO"
    echo "Certificados generados."
else
    echo " Certificados ya existen."
fi

# 4. Instrucciones Finales
echo "ENTORNO LISTO."
echo "Levanta el proyecto:  podman-compose up -d"











