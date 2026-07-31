package org.dspace.authenticate;

import static org.apache.commons.lang.BooleanUtils.toBoolean;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;

import jakarta.servlet.http.HttpServletRequest;

import org.apache.commons.lang3.StringUtils;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
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
 * Extension de OidcAuthenticationBean para el SIC (VRIIC USACH).
 *
 * Agrega dos comportamientos que la clase base de DSpace-CRIS 8 no provee:
 *
 *  1. Persiste los claims "rut" y "tipo" (entregados por Keycloak, realm DEI)
 *     como metadata del EPerson (eperson.rut / eperson.tipo), actualizandolos
 *     en CADA login -- no solo al crear el usuario por primera vez.
 *
 *  2. Sincroniza, en cada login, la membresia REAL y PERSISTENTE (no un
 *     special group de sesion) del EPerson en el grupo de DSpace cuyo nombre
 *     coincide con el valor de "tipo" (ej: "ADMINISTRATIVO", "DEPARTAMENTAL").
 *     Si el "tipo" cambio respecto del ultimo login, se remueve la membresia
 *     del grupo anterior y se agrega al nuevo. El grupo debe existir de
 *     antemano en DSpace, salvo que se habilite
 *     authentication-oidc.tipo.autocreate-group=true.
 *
 *     Nota importante: al ser membresia persistida (no special group), no se
 *     revoca sola si la persona deja de loguearse por OIDC -- el "limpiado"
 *     del grupo anterior solo ocurre en el momento de un login posterior con
 *     un "tipo" distinto.
 *
 * No se pudo extender directamente authenticateWithOidc() de la clase base
 * porque es privado, y el "code" de OIDC es de un solo uso: no se puede
 * reutilizar el que ya proceso el padre. Por eso authenticate() se
 * reimplementa completo, apoyandose en getOidcClient() (publico) para
 * repetir el intercambio code -> token -> userinfo.
 *
 * @author VRIIC USACH
 */
public class SicOidcAuthenticationBean extends OidcAuthenticationBean {

    private static final Logger LOGGER = LogManager.getLogger();

    private static final String OIDC_AUTHENTICATED = "oidc.authenticated";

    private static final String EPERSON_METADATA_SCHEMA = "eperson";
    private static final String RUT_METADATA_ELEMENT = "rut";
    private static final String TIPO_METADATA_ELEMENT = "tipo";

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

        String email = getAttributeAsString(userInfo, getConfigProperty("authentication-oidc.user-info.email",
                "email"));
        if (StringUtils.isBlank(email)) {
            LOGGER.warn("No email found in the user info attributes");
            return NO_SUCH_USER;
        }

        EPersonService ePersonService = EPersonServiceFactory.getInstance().getEPersonService();
        EPerson ePerson = ePersonService.findByEmail(context, email);

        if (ePerson != null) {
            updateClaimsAndSyncGroupMembership(context, ePersonService, ePerson, userInfo);
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

        return registerNewEPersonWithClaims(context, ePersonService, userInfo, email, request);
    }

    private int registerNewEPersonWithClaims(Context context, EPersonService ePersonService,
            Map<String, Object> userInfo, String email, HttpServletRequest request) throws SQLException {

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

            updateClaimsAndSyncGroupMembership(context, ePersonService, eperson, userInfo);

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
            EPerson ePerson, Map<String, Object> userInfo) throws SQLException {

        String rutAttribute = getConfigProperty("authentication-oidc.user-info.rut", "rut");
        String tipoAttribute = getConfigProperty("authentication-oidc.user-info.tipo", "tipo");

        String rut = getAttributeAsString(userInfo, rutAttribute);
        String tipo = getAttributeAsString(userInfo, tipoAttribute);

        if (StringUtils.isBlank(rut) && StringUtils.isBlank(tipo)) {
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
            removeGroupMembershipIfPresent(context, ePerson, previousTipo);
        }

        ensureGroupMembership(context, ePerson, currentTipo);
    }

    private void ensureGroupMembership(Context context, EPerson ePerson, String tipo)
            throws SQLException, AuthorizeException {

        Group group = resolveOrCreateTipoGroup(context, tipo);
        if (group == null) {
            return;
        }

        GroupService groupService = EPersonServiceFactory.getInstance().getGroupService();
        if (!groupService.isDirectMember(group, ePerson)) {
            groupService.addMember(context, group, ePerson);
            groupService.update(context, group);
            LOGGER.info("Added EPerson {} to DSpace group '{}' (tipo={})", ePerson.getEmail(), group.getName(),
                    tipo);
        }
    }

    private void removeGroupMembershipIfPresent(Context context, EPerson ePerson, String tipo)
            throws SQLException, AuthorizeException {

        GroupService groupService = EPersonServiceFactory.getInstance().getGroupService();
        Group group = groupService.findByName(context, buildGroupName(tipo));
        if (group != null && groupService.isDirectMember(group, ePerson)) {
            groupService.removeMember(context, group, ePerson);
            groupService.update(context, group);
            LOGGER.info("Removed EPerson {} from DSpace group '{}' (tipo changed away from {})",
                    ePerson.getEmail(), group.getName(), tipo);
        }
    }

    private Group resolveOrCreateTipoGroup(Context context, String tipo) throws SQLException, AuthorizeException {
        GroupService groupService = EPersonServiceFactory.getInstance().getGroupService();
        String groupName = buildGroupName(tipo);
        Group group = groupService.findByName(context, groupName);

        boolean autoCreate = toBoolean(getConfigProperty("authentication-oidc.tipo.autocreate-group", "false"));
        if (group == null && autoCreate) {
            group = groupService.create(context);
            groupService.setName(group, groupName);
            groupService.update(context, group);
            LOGGER.info("Auto-created DSpace group '{}' for OIDC tipo claim '{}'", groupName, tipo);
        }

        if (group == null) {
            LOGGER.warn("No DSpace group named '{}' found for OIDC tipo claim '{}' -- skipping group assignment",
                    groupName, tipo);
        }

        return group;
    }

    private String buildGroupName(String tipo) {
        String groupPrefix = getConfigProperty("authentication-oidc.tipo.group-prefix", "");
        return groupPrefix + tipo;
    }

    // getSpecialGroups() no se sobrescribe: se hereda el List.of() de OidcAuthenticationBean.
    // Ya no hace falta un "special group" de sesion -- la membresia queda persistida
    // en cada login por syncTipoGroupMembership(), y DSpace la resuelve como cualquier
    // otra membresia real (via GroupService.allMemberGroups / isMember).

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
