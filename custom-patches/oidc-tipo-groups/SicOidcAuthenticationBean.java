package org.dspace.authenticate;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import org.apache.commons.lang3.BooleanUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.dspace.authenticate.oidc.OidcClient;
import org.dspace.authenticate.oidc.model.OidcTokenResponseDTO;
import org.dspace.authorize.AuthorizeException;
import org.dspace.content.Item;
import org.dspace.content.MetadataValue;
import org.dspace.core.Context;
import org.dspace.eperson.EPerson;
import org.dspace.eperson.Group;
import org.dspace.eperson.factory.EPersonServiceFactory;
import org.dspace.eperson.service.EPersonService;
import org.dspace.eperson.service.GroupService;
import org.dspace.services.factory.DSpaceServicesFactory;

/**
 * Bean de autenticacion OIDC personalizado para el SIC USACH.
 *
 * Extiende OidcAuthenticationBean de 4Science para:
 *   - Persistir metadatos eperson.rut y eperson.tipo desde los claims de Keycloak.
 *   - Sincronizar membresia de grupos en base al claim "tipo".
 *   - Validar acceso contra la API de estamento de la DEI (fail-closed por defecto).
 *
 * Nota debug: incluye dump de userInfo tras getUserInfo() para diagnostico
 * de claims de Keycloak (SIC-OIDC-USERINFO en logs). RUT enmascarado a los
 * ultimos 4 digitos por privacidad. Remover o bajar a DEBUG una vez validado.
 */
public class SicOidcAuthenticationBean extends OidcAuthenticationBean {

    private static final Logger LOGGER = LogManager.getLogger();

    private static final String OIDC_AUTHENTICATED = "oidc.authenticated";

    private static final String EPERSON_METADATA_SCHEMA = "eperson";
    private static final String RUT_METADATA_ELEMENT = "rut";
    private static final String TIPO_METADATA_ELEMENT = "tipo";

    private static final HttpClient HTTP_CLIENT = HttpClient.newHttpClient();
    private static final ObjectMapper JSON_MAPPER = new ObjectMapper();

    @Override
    public int authenticate(Context context, String username, String password, String realm,
                            HttpServletRequest request) throws SQLException {

        if (request == null) {
            LOGGER.warn("Unable to authenticate using OIDC because the request object is null.");
            return BAD_ARGS;
        }

        if (request.getAttribute(OIDC_AUTH_ATTRIBUTE) == null) {
            return NO_SUCH_USER;
        }

        String code = request.getParameter("code");
        if (StringUtils.isEmpty(code)) {
            LOGGER.warn("The incoming request has not code parameter");
            return NO_SUCH_USER;
        }

        return authenticateWithOidcAndCaptureClaims(context, code, request);
    }

    private int authenticateWithOidcAndCaptureClaims(Context context, String code, HttpServletRequest request)
            throws SQLException {

        OidcTokenResponseDTO accessToken;
        try {
            accessToken = getOidcClient().getAccessToken(code);
        } catch (Exception ex) {
            LOGGER.error("An error occurs retrieving the OIDC access_token", ex);
            return NO_SUCH_USER;
        }

        if (accessToken == null) {
            LOGGER.warn("No access token retrieved by code");
            return NO_SUCH_USER;
        }

        Map<String, Object> userInfo;
        try {
            userInfo = getOidcClient().getUserInfo(accessToken.getAccessToken());
        } catch (Exception ex) {
            LOGGER.error("An error occurs retrieving the OIDC user info", ex);
            return NO_SUCH_USER;
        }

        // ------------------------------------------------------------------
        // DEBUG: dump completo de claims recibidos desde Keycloak.
        // Sirve para descubrir claims adicionales (facultad, departamento,
        // roles, etc.) que hoy no procesamos y validar tipo Java real de
        // cada valor (String vs List vs Map). RUT se enmascara a los
        // ultimos 4 digitos por privacidad.
        // Remover o bajar a DEBUG una vez validado.
        // ------------------------------------------------------------------
        logUserInfoClaims(userInfo);
        // ------------------------------------------------------------------

        String email = getAttributeAsString(userInfo, getConfigProperty("authentication-oidc.user-info.email",
                "email"));
        if (StringUtils.isBlank(email)) {
            LOGGER.warn("No email found in the user info attributes");
            return NO_SUCH_USER;
        }

        // --- Validacion contra API de estamento (switch) ---
        EstamentoResult estamentoResult = null;
        if (isEstamentoValidationEnabled()) {
            String rutForValidation = getAttributeAsString(userInfo,
                    getConfigProperty("authentication-oidc.user-info.rut", "rut"));
            estamentoResult = consultarEstamento(rutForValidation, email);

            if (estamentoResult == null || estamentoResult.isEmpty()) {
                LOGGER.warn("Login OIDC rechazado: RUT {} no figura activo segun la API de estamento",
                        rutForValidation);
                return NO_SUCH_USER;
            }
        }
        // --- fin validacion API de estamento ---

        EPersonService ePersonService = EPersonServiceFactory.getInstance().getEPersonService();
        EPerson ePerson = ePersonService.findByEmail(context, email);

        if (ePerson != null) {
            updateClaimsAndSyncGroupMembership(context, ePersonService, ePerson, userInfo, estamentoResult);
            request.setAttribute(OIDC_AUTHENTICATED, true);
            context.setCurrentUser(ePerson);
            return ePerson.canLogIn() ? SUCCESS : BAD_ARGS;
        }

        boolean canSelfRegister = toBoolean(getConfigProperty("authentication-oidc.can-self-register", "true"));
        if (!canSelfRegister) {
            LOGGER.warn("Self registration is currently disabled for OIDC, and no ePerson could be found "
                    + "for email: {}", email);
            return NO_SUCH_USER;
        }

        return registerNewEPersonWithClaims(context, ePersonService, userInfo, email, request, estamentoResult);
    }

    /**
     * Loguea todos los claims recibidos en userInfo, uno por linea, incluyendo
     * el tipo Java del valor para detectar claims multi-valued (List/Map) que
     * getAttributeAsString serializaria de forma incorrecta.
     *
     * Enmascara el valor del RUT/RUN a los ultimos 4 digitos.
     */
    private void logUserInfoClaims(Map<String, Object> userInfo) {
        if (userInfo == null) {
            LOGGER.warn("SIC-OIDC-USERINFO userInfo is null");
            return;
        }
        LOGGER.info("SIC-OIDC-USERINFO keys={}", userInfo.keySet());
        userInfo.forEach((k, v) -> {
            String safeValue;
            String type;
            if (v == null) {
                safeValue = "null";
                type = "null";
            } else {
                type = v.getClass().getSimpleName();
                if ("rut".equalsIgnoreCase(k) || "run".equalsIgnoreCase(k)) {
                    String s = String.valueOf(v);
                    safeValue = s.length() > 4 ? "****" + s.substring(s.length() - 4) : "****";
                } else {
                    safeValue = String.valueOf(v);
                }
            }
            LOGGER.info("SIC-OIDC-USERINFO   {} = [{}] (type={})", k, safeValue, type);
        });
    }

    private int registerNewEPersonWithClaims(Context context, EPersonService ePersonService,
                                             Map<String, Object> userInfo, String email, HttpServletRequest request, EstamentoResult estamentoResult)
            throws SQLException {

        try {
            context.turnOffAuthorisationSystem();

            EPerson eperson = ePersonService.create(context);
            eperson.setNetid(email);
            eperson.setEmail(email);

            String firstName = getAttributeAsString(userInfo,
                    getConfigProperty("authentication-oidc.user-info.first-name", "given_name"));
            if (firstName != null) {
                eperson.setFirstName(context, firstName);
            }

            String lastName = getAttributeAsString(userInfo,
                    getConfigProperty("authentication-oidc.user-info.last-name", "family_name"));
            if (lastName != null) {
                eperson.setLastName(context, lastName);
            }

            eperson.setCanLogIn(true);
            eperson.setSelfRegistered(true);

            updateClaimsAndSyncGroupMembership(context, ePersonService, eperson, userInfo, estamentoResult);

            ePersonService.update(context, eperson);
            context.setCurrentUser(eperson);
            context.dispatchEvents();

            request.setAttribute(OIDC_AUTHENTICATED, true);

            return SUCCESS;
        } catch (Exception ex) {
            LOGGER.error("An error occurs registering a new EPerson from OIDC", ex);
            return NO_SUCH_USER;
        } finally {
            context.restoreAuthSystemState();
        }
    }

    private void updateClaimsAndSyncGroupMembership(Context context, EPersonService ePersonService,
                                                    EPerson ePerson, Map<String, Object> userInfo, EstamentoResult estamentoResult) throws SQLException {

        String rutAttribute = getConfigProperty("authentication-oidc.user-info.rut", "rut");
        String tipoAttribute = getConfigProperty("authentication-oidc.user-info.tipo", "tipo");

        String rut = getAttributeAsString(userInfo, rutAttribute);
        String tipo = getAttributeAsString(userInfo, tipoAttribute);

        if (StringUtils.isBlank(rut) && StringUtils.isBlank(tipo) && estamentoResult == null) {
            return;
        }

        // turnOffAuthorisationSystem es seguro de anidar (DSpace Context usa una pila
        // interna): si el llamador (ej. registerNewEPersonWithClaims) ya la desactivo,
        // este bloque no la reactiva antes de tiempo al hacer restoreAuthSystemState().
        try {
            context.turnOffAuthorisationSystem();

            String previousTipo = getCurrentTipoValue(ePersonService, ePerson);

            if (StringUtils.isNotBlank(rut)) {
                ePersonService.setMetadataSingleValue(context, ePerson, EPERSON_METADATA_SCHEMA,
                        RUT_METADATA_ELEMENT, null, null, rut);
            }

            if (StringUtils.isNotBlank(tipo)) {
                ePersonService.setMetadataSingleValue(context, ePerson, EPERSON_METADATA_SCHEMA,
                        TIPO_METADATA_ELEMENT, null, null, tipo);
            }

            ePersonService.update(context, ePerson);

            if (StringUtils.isNotBlank(tipo)) {
                syncTipoGroupMembership(context, ePerson, previousTipo, tipo);
            }

            if (estamentoResult != null && StringUtils.isNotBlank(estamentoResult.getEstamento())) {
                syncEstamentoGroupMembership(context, ePerson, estamentoResult.getEstamento());
            }
        } catch (AuthorizeException ex) {
            LOGGER.error("Not authorized to update rut/tipo metadata or group membership for EPerson {}",
                    ePerson.getEmail(), ex);
        } finally {
            context.restoreAuthSystemState();
        }
    }

    private String getCurrentTipoValue(EPersonService ePersonService, EPerson ePerson) {
        List<MetadataValue> values = ePersonService.getMetadata(ePerson, EPERSON_METADATA_SCHEMA,
                TIPO_METADATA_ELEMENT, null, Item.ANY);
        return values.isEmpty() ? null : values.get(0).getValue();
    }

    /**
     * Asegura que el EPerson quede como miembro PERSISTENTE (no special group) del
     * grupo de DSpace correspondiente al "tipo" actual, y lo remueve del grupo del
     * "tipo" anterior si cambio respecto del ultimo login. Este metodo requiere que
     * el llamador ya haya desactivado el sistema de autorizacion (turnOffAuthorisationSystem).
     */
    private void syncTipoGroupMembership(Context context, EPerson ePerson, String previousTipo, String currentTipo)
            throws SQLException, AuthorizeException {

        if (!StringUtils.equals(previousTipo, currentTipo) && StringUtils.isNotBlank(previousTipo)) {
            removeGroupMembershipIfPresent(context, ePerson, buildTipoGroupName(previousTipo));
        }

        ensureGroupMembership(context, ePerson, buildTipoGroupName(currentTipo),
                "authentication-oidc.tipo.autocreate-group", "tipo=" + currentTipo);
    }

    /**
     * Analogo a syncTipoGroupMembership pero para el estamento devuelto por la
     * API de la DEI. No maneja "estamento anterior" porque, a diferencia de
     * "tipo" (que viene siempre en el claim de Keycloak), el estamento solo se
     * conoce cuando el switch esta habilitado -- por ahora simplemente asegura
     * la membresia actual sin remover membresias de estamentos previos. Si en
     * el futuro un estamento puede cambiar entre logins (ej. un estudiante que
     * pasa a funcionario), replicar aqui la logica de removeGroupMembershipIfPresent
     * que ya usa syncTipoGroupMembership.
     */
    private void syncEstamentoGroupMembership(Context context, EPerson ePerson, String estamento)
            throws SQLException, AuthorizeException {

        ensureGroupMembership(context, ePerson, buildEstamentoGroupName(estamento),
                "authentication-oidc.estamento.autocreate-group", "estamento=" + estamento);
    }

    private void ensureGroupMembership(Context context, EPerson ePerson, String groupName,
                                       String autocreateProperty, String logSuffix) throws SQLException, AuthorizeException {

        Group group = resolveOrCreateGroup(context, groupName, autocreateProperty);
        if (group == null) {
            return;
        }

        GroupService groupService = EPersonServiceFactory.getInstance().getGroupService();
        if (!groupService.isDirectMember(group, ePerson)) {
            groupService.addMember(context, group, ePerson);
            groupService.update(context, group);
            LOGGER.info("Added EPerson {} to DSpace group '{}' ({})", ePerson.getEmail(), group.getName(),
                    logSuffix);
        }
    }

    private void removeGroupMembershipIfPresent(Context context, EPerson ePerson, String groupName)
            throws SQLException, AuthorizeException {

        GroupService groupService = EPersonServiceFactory.getInstance().getGroupService();
        Group group = groupService.findByName(context, groupName);
        if (group != null && groupService.isDirectMember(group, ePerson)) {
            groupService.removeMember(context, group, ePerson);
            groupService.update(context, group);
            LOGGER.info("Removed EPerson {} from DSpace group '{}' (previous value changed)",
                    ePerson.getEmail(), group.getName());
        }
    }

    private Group resolveOrCreateGroup(Context context, String groupName, String autocreateProperty)
            throws SQLException, AuthorizeException {

        GroupService groupService = EPersonServiceFactory.getInstance().getGroupService();
        Group group = groupService.findByName(context, groupName);

        boolean autoCreate = toBoolean(getConfigProperty(autocreateProperty, "false"));
        if (group == null && autoCreate) {
            group = groupService.create(context);
            groupService.setName(group, groupName);
            groupService.update(context, group);
            LOGGER.info("Auto-created DSpace group '{}'", groupName);
        }

        if (group == null) {
            LOGGER.warn("No DSpace group named '{}' found -- skipping group assignment", groupName);
        }

        return group;
    }

    private String buildTipoGroupName(String tipo) {
        String groupPrefix = getConfigProperty("authentication-oidc.tipo.group-prefix", "");
        return groupPrefix + tipo;
    }

    // Prefijo por defecto "EST_" para no colisionar con los grupos por "tipo": la
    // API de estamento puede devolver "ADMINISTRATIVO", que es el mismo valor que
    // ya usa un grupo de "tipo" existente. Mientras no este confirmado con Rodrigo
    // si ambos deben apuntar al mismo grupo o no, se mantienen separados.
    private String buildEstamentoGroupName(String estamento) {
        String groupPrefix = getConfigProperty("authentication-oidc.estamento.group-prefix", "EST_");
        return groupPrefix + estamento;
    }

    // getSpecialGroups() no se sobrescribe: se hereda el List.of() de OidcAuthenticationBean.
    // Ya no hace falta un "special group" de sesion -- la membresia queda persistida
    // en cada login por syncTipoGroupMembership() / syncEstamentoGroupMembership(),
    // y DSpace la resuelve como cualquier otra membresia real (via
    // GroupService.allMemberGroups / isMember).

    private boolean isEstamentoValidationEnabled() {
        return toBoolean(getConfigProperty("authentication-oidc.estamento.enabled", "false"));
    }

    private EstamentoResult consultarEstamento(String rut, String requestingUserEmail) {
        if (StringUtils.isBlank(rut)) {
            LOGGER.warn("No se puede consultar la API de estamento sin RUT (requestinguser={})",
                    requestingUserEmail);
            return failClosedOrOpen();
        }

        String baseUrl = getConfigProperty("authentication-oidc.estamento.base-url",
                "https://udatos.dei.usach.cl");
        String username = getConfigProperty("authentication-oidc.estamento.username", "sic-estamento");
        String password = getConfigProperty("authentication-oidc.estamento.password", "");

        try {
            String token = obtenerTokenEstamento(baseUrl, username, password, requestingUserEmail);
            if (StringUtils.isBlank(token)) {
                return failClosedOrOpen();
            }
            return consultarActivoEstamento(baseUrl, token, rut);
        } catch (Exception ex) {
            LOGGER.error("Error consultando la API de estamento para RUT {}", rut, ex);
            return failClosedOrOpen();
        }
    }

    // Si la API falla (timeout, 5xx, credenciales invalidas, etc.) esto decide si
    // se rechaza el login (fail-closed, por defecto) o se deja pasar sin bloquear
    // (fail-open, sin sincronizar grupo por estamento). Fail-closed es lo mas
    // seguro pero implica que una caida de la API de DEI tumba el login del SIC
    // completo -- CONFIRMAR CON RODRIGO si eso es aceptable o si se prefiere
    // fail-open con alguna alerta/monitoreo aparte.
    private EstamentoResult failClosedOrOpen() {
        boolean failOpen = toBoolean(getConfigProperty("authentication-oidc.estamento.fail-open", "false"));
        return failOpen ? EstamentoResult.activoDesconocido() : EstamentoResult.inactivo();
    }

    private String obtenerTokenEstamento(String baseUrl, String username, String password, String requestingUser)
            throws Exception {

        // TODO: confirmar con Felipe/Javier si "requestinguser" debe ser el correo
        // del EPerson que se esta autenticando (asumido aqui) o una cuenta de
        // servicio fija del SIC.
        String payload = JSON_MAPPER.writeValueAsString(Map.of(
                "username", username,
                "password", password,
                "requestinguser", requestingUser
        ));

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + "/api/login"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(payload))
                .build();

        HttpResponse<String> response = HTTP_CLIENT.send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() != 200) {
            LOGGER.error("Login en API de estamento fallo con status {}: {}", response.statusCode(),
                    response.body());
            return null;
        }

        // TODO: el nombre exacto del campo del token en la respuesta no esta
        // confirmado por Felipe -- se asume "token". Verificar contra una
        // respuesta real antes de habilitar el switch en produccion.
        JsonNode json = JSON_MAPPER.readTree(response.body());
        JsonNode tokenNode = json.path("token");
        return tokenNode.isMissingNode() ? null : tokenNode.asText(null);
    }

    private EstamentoResult consultarActivoEstamento(String baseUrl, String token, String rut) throws Exception {
        String payload = JSON_MAPPER.writeValueAsString(Map.of("run", rut));

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + "/api/estamento/activo"))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + token)
                .method("GET", HttpRequest.BodyPublishers.ofString(payload))
                .build();

        HttpResponse<String> response = HTTP_CLIENT.send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() != 200) {
            LOGGER.error("Consulta a API de estamento fallo con status {}: {}", response.statusCode(),
                    response.body());
            return failClosedOrOpen();
        }

        JsonNode json = JSON_MAPPER.readTree(response.body());
        String estamento = json.path("estamento").asText(null);

        return StringUtils.isBlank(estamento) ? EstamentoResult.inactivo() : EstamentoResult.activo(estamento);
    }

    /**
     * Resultado de la consulta a la API de estamento. isEmpty() == true significa
     * "no activo" o "sin estamento" -- la API de la DEI no distingue entre ambos
     * casos, ambos devuelven la misma estructura vacia.
     */
    private static final class EstamentoResult {

        private final boolean activo;
        private final String estamento;

        private EstamentoResult(boolean activo, String estamento) {
            this.activo = activo;
            this.estamento = estamento;
        }

        static EstamentoResult activo(String estamento) {
            return new EstamentoResult(true, estamento);
        }

        static EstamentoResult inactivo() {
            return new EstamentoResult(false, null);
        }

        // Usado solo en modo fail-open: deja pasar el login sin estamento conocido
        // (no se sincroniza grupo por estamento en ese caso).
        static EstamentoResult activoDesconocido() {
            return new EstamentoResult(true, null);
        }

        boolean isEmpty() {
            return !activo;
        }

        String getEstamento() {
            return estamento;
        }
    }

    private String getAttributeAsString(Map<String, Object> userInfo, String attribute) {
        if (StringUtils.isBlank(attribute)) {
            return null;
        }
        return userInfo.containsKey(attribute) ? String.valueOf(userInfo.get(attribute)) : null;
    }

    private String getConfigProperty(String property, String defaultValue) {
        return DSpaceServicesFactory.getInstance().getConfigurationService().getProperty(property, defaultValue);
    }
}