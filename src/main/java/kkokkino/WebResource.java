package kkokkino;

import org.eclipse.microprofile.config.inject.ConfigProperty;

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.Response;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

@Path("/")
@Produces("*/*")
public class WebResource {

    @ConfigProperty(name = "app.pg_string")
    String pg_string;

    @ConfigProperty(name = "app.pg_user")
    String pg_user;

    @ConfigProperty(name = "app.pg_pass")
    String pg_pass;

    @GET
    @Path("/health")
    public Response health() {
        return Response.ok().build();
    }

    @GET
    @Path("/ready")
    public Response ready() {
        try (Connection con = DriverManager.getConnection(pg_string, pg_user, pg_pass)) {
            return Response.ok().build();
        } catch (SQLException e) {
            e.printStackTrace();
            return Response.status(Response.Status.SERVICE_UNAVAILABLE).build();
        }
    }
}