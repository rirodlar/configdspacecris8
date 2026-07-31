# Patch manual: OIDC rut/tipo + asignación automática de grupos

Este patch NO forma parte del build oficial de DSpace-CRIS (`dspace-cris-back`).
Se aplica manualmente sobre el servidor `dispacecris`. Si el sistema se
reinstala desde cero, hay que reaplicarlo siguiendo estos pasos.

## Qué hace

Reemplaza el bean `oidcAuthentication` (normalmente
`org.dspace.authenticate.OidcAuthenticationBean`) por
`SicOidcAuthenticationBean`, que además de loguear al usuario:

- Guarda los claims `rut` y `tipo` (entregados por Keycloak, realm DEI)
  como metadata del EPerson (`eperson.rut`, `eperson.tipo`), en cada login.
- Sincroniza la membresía real (persistida, no special group) del usuario
  al grupo de DSpace con el mismo nombre que su `tipo` actual
  (ej. `ADMINISTRATIVO`, `DEPARTAMENTAL`), migrándolo automáticamente
  si el `tipo` cambia entre logins.

## Requisitos previos

- Deben existir en DSpace los grupos correspondientes a cada valor posible
  de `tipo` (hoy: `ADMINISTRATIVO`, `DEPARTAMENTAL`). Si no existen y se
  quiere que se creen solos, activar
  `authentication-oidc.tipo.autocreate-group = true`.
- El OIDC básico (login) debe estar ya configurado y funcionando
  (`authentication-oidc.cfg`, realm DEI, client `sic-usach`).

## Pasos de instalación

### 1. Registrar la metadata del EPerson (una sola vez, no se pierde en redeploys de código, pero sí en un `dspace database clean`/reinstalación de BD)

```sql
INSERT INTO metadatafieldregistry (metadata_schema_id, element, qualifier, scope_note)
VALUES ((SELECT metadata_schema_id FROM metadataschemaregistry WHERE short_id='eperson'), 'rut', NULL, 'RUT institucional (Keycloak DEI)');

INSERT INTO metadatafieldregistry (metadata_schema_id, element, qualifier, scope_note)
VALUES ((SELECT metadata_schema_id FROM metadataschemaregistry WHERE short_id='eperson'), 'tipo', NULL, 'Estamento (Keycloak DEI)');
```

Verificar:

```sql
SELECT element, qualifier FROM metadatafieldregistry WHERE metadata_schema_id =
  (SELECT metadata_schema_id FROM metadataschemaregistry WHERE short_id='eperson') AND element IN ('rut','tipo');
```

### 2. Compilar la clase

Requiere los jars de la instalación de DSpace-CRIS ya desplegados (no
necesita Maven ni acceso a internet):

```bash
mkdir -p /tmp/siccustomauth/org/dspace/authenticate
cp SicOidcAuthenticationBean.java /tmp/siccustomauth/org/dspace/authenticate/
cd /tmp/siccustomauth
javac -cp "/dspacecris8/webapps/server/WEB-INF/lib/*:/dspacecris8/lib/jakarta.servlet-api-6.1.0.jar" \
  -d . org/dspace/authenticate/SicOidcAuthenticationBean.java
jar cf sic-oidc-custom.jar org
```

Nota: el jar `jakarta.servlet-api-6.1.0.jar` vive en `/dspacecris8/lib/`, no
en `WEB-INF/lib/` (que solo trae la versión vieja `javax.servlet-api`). Sin
esa ruta explícita, la compilación falla con
`package jakarta.servlet.http does not exist`.

### 3. Desplegar el jar

IMPORTANTE: Tomcat corre desde `/opt/tomcat/webapps/server/`, NO desde
`/dspacecris8/webapps/server/` (son dos árboles de directorios separados,
no un symlink). Copiar a ambos para que el classpath real de Tomcat lo vea:

```bash
sudo cp sic-oidc-custom.jar /opt/tomcat/webapps/server/WEB-INF/lib/
sudo cp sic-oidc-custom.jar /dspacecris8/lib/
```

### 4. Editar el bean de Spring

```bash
sudo sed -i 's|org.dspace.authenticate.OidcAuthenticationBean|org.dspace.authenticate.SicOidcAuthenticationBean|' \
  /dspacecris8/config/spring/api/core-services.xml
```

Confirmar que quedó bien (debería mostrar `SicOidcAuthenticationBean`):

```bash
grep -n "OidcAuthentication" /dspacecris8/config/spring/api/core-services.xml
```

### 5. Reiniciar y validar

```bash
BEFORE=$(sudo wc -l /opt/tomcat/logs/catalina.out | awk '{print $1}')
sudo systemctl restart tomcat
sleep 40
sudo tail -n +$((BEFORE+1)) /opt/tomcat/logs/catalina.out | \
  grep -n "SicOidc\|Exception\|Deployment of web application directory \[/opt/tomcat/webapps/server\]"
curl -s -o /dev/null -w "%{http_code}\n" https://sic.usach.cl/server/api/authn/status
```

Debe verse solo la línea de "Deployment... has finished", sin excepciones,
y el curl debe devolver `200`.

### 6. Crear los grupos de destino (si no existen)

Desde la UI de administración → People → Groups → Create, con nombre
exactamente igual al valor de `tipo` (ej. `ADMINISTRATIVO`,
`DEPARTAMENTAL`).

## Verificación end-to-end

Después de un login real (cerrando sesión primero si ya había una activa):

```sql
-- metadata capturada
SELECT mfr.element, mv.text_value FROM metadatavalue mv
 JOIN metadatafieldregistry mfr ON mv.metadata_field_id = mfr.metadata_field_id
 JOIN eperson e ON mv.dspace_object_id = e.uuid
 WHERE e.email = '<email de prueba>' AND mfr.element IN ('rut','tipo');

-- membresía persistida en el grupo
SELECT g.name, e.email FROM epersongroup2eperson eg
 JOIN epersongroup g ON eg.eperson_group_id = g.uuid
 JOIN eperson e ON eg.eperson_id = e.uuid
 WHERE e.email = '<email de prueba>';
```

## Configuración opcional (local.cfg)

```properties
# Nombres de los atributos en la respuesta de Keycloak /userinfo (defaults: rut, tipo)
authentication-oidc.user-info.rut = rut
authentication-oidc.user-info.tipo = tipo

# Prefijo opcional para el nombre del grupo de DSpace (default: sin prefijo,
# el grupo debe llamarse exactamente igual al valor de "tipo")
authentication-oidc.tipo.group-prefix =

# Si el grupo correspondiente al tipo no existe, crearlo automáticamente
# (default: false)
authentication-oidc.tipo.autocreate-group = false
```

## Historial

- 2026-07-27/28: Desarrollo y validación inicial. Probado end-to-end con
  cuenta de tipo ADMINISTRATIVO (ricardo.rodriguez.l@usach.cl). Pendiente
  validar con cuenta de tipo DEPARTAMENTAL.
