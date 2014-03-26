package de.anycook.api.backend;

import de.anycook.db.mysql.DBRecipe;
import de.anycook.status.Status;
import org.apache.log4j.Logger;

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.WebApplicationException;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import java.sql.SQLException;


@Path("backend/status")
public class StatusApi {

    private final Logger logger;

    public StatusApi() {
        logger = Logger.getLogger(getClass());
    }

    @GET
	@Produces(MediaType.APPLICATION_JSON)
	public Status getStatus(){
        try {
            return new Status();
        } catch (SQLException | DBRecipe.RecipeNotFoundException e) {
            logger.error(e, e);
            throw new WebApplicationException(Response.Status.INTERNAL_SERVER_ERROR);
        }
    }
}