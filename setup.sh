# ==============================================================================
# Script de Inicialización de Entorno: Traefik + Podman
# Propósito: Generar estructura de directorios, certificados SSL y configuración
#            dinámica de Traefik basada en variables de entorno (.env).
# ==============================================================================

# Configuración del Dominio Base
DOMINIO="cienciadedatos.inegi.org.mx"

echo "[INFO] Iniciando configuracion del laboratorio..."

# ------------------------------------------------------------------------------
# 1. Creación de Estructura de Directorios
# ------------------------------------------------------------------------------
echo "[INFO] Verificando directorios..."
mkdir -p certs traefik proyecto1 proyecto2

# ------------------------------------------------------------------------------
# 2. Generación de Archivo de Entorno (.env)
# ------------------------------------------------------------------------------
if [ ! -f .env ]; then
    echo "[INFO] El archivo .env no existe. Creando uno base..."
    cat <<EOF > .env
# Definicion de Rutas Externas
# Formato: APP_NOMBRE=URL_DESTINO
APP_GEOASISTENTE=http://10.152.11.81:8010
APP_GOOGLE=https://www.google.com
EOF
fi

# ------------------------------------------------------------------------------
# 3. Generación de Certificados SSL (OpenSSL)
# ------------------------------------------------------------------------------
if [ ! -f certs/local.key ]; then
    echo "[INFO] Generando certificados SSL autofirmados para: $DOMINIO"
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -keyout certs/local.key \
        -out certs/local.crt \
        -subj "/CN=$DOMINIO" 2>/dev/null
    echo "[OK] Certificados generados en el directorio /certs."
else
    echo "[INFO] Los certificados SSL ya existen."
fi

# ------------------------------------------------------------------------------
# 4. Generador de Configuración Dinámica de Traefik
# ------------------------------------------------------------------------------
echo "[INFO] Generando archivo de configuracion dinamica (dynamic_conf.yml)..."

CONFIG_FILE="traefik/dynamic_conf.yml"

# 4.1. Escritura de Cabecera y Configuración TLS
cat <<EOF > $CONFIG_FILE
tls:
  stores:
    default:
      defaultCertificate:
        certFile: /etc/traefik/certs/local.crt
        keyFile: /etc/traefik/certs/local.key

http:
  routers:
EOF

# 4.2. Generación de Routers
while IFS='=' read -r key value; do
  # Ignorar comentarios y líneas vacías
  [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]] && continue

  if [[ $key == APP_* ]]; then
    # Normalización del nombre (APP_TEST -> test)
    APP_NAME=$(echo "${key#APP_}" | tr '[:upper:]' '[:lower:]')
    echo "   -> Agregando ruta externa: /laboratorio/$APP_NAME hacia $value"

    cat <<EOF >> $CONFIG_FILE
    router-$APP_NAME:
      rule: "PathPrefix(\`/laboratorio/$APP_NAME\`)"
      service: service-$APP_NAME
      entryPoints: [web, websecure]
      tls: true
      middlewares: [strip-$APP_NAME]
EOF
  fi
done < .env

# 4.3. Generación de Services
echo "  services:" >> $CONFIG_FILE

while IFS='=' read -r key value; do
  [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]] && continue
  if [[ $key == APP_* ]]; then
    APP_NAME=$(echo "${key#APP_}" | tr '[:upper:]' '[:lower:]')
    # Limpieza de caracteres
    URL=$(echo "$value" | tr -d '\r')

    cat <<EOF >> $CONFIG_FILE
    service-$APP_NAME:
      loadBalancer:
        servers:
          - url: "$URL"
EOF
  fi
done < .env

# 4.4. Generación de Middlewares
echo "  middlewares:" >> $CONFIG_FILE

while IFS='=' read -r key value; do
  [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]] && continue
  if [[ $key == APP_* ]]; then
    APP_NAME=$(echo "${key#APP_}" | tr '[:upper:]' '[:lower:]')

    cat <<EOF >> $CONFIG_FILE
    strip-$APP_NAME:
      stripPrefix:
        prefixes: ["/laboratorio/$APP_NAME"]
EOF
  fi
done < .env

echo "[OK] Archivo de configuracion generado exitosamente."
echo "===================================================="
echo "Configuracion finalizada."
echo "Ejecute: podman-compose up -d"
echo "===================================================="
