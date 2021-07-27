package com.redhat.workItem;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.equalTo;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.MatcherAssert.assertThat;

@QuarkusTest
public class ServiceResourceTest {

    @Test
    public void testDoYourServiceEndpoint() {
        Item[] result = given()
                .when().accept(ContentType.JSON).
                        get("/doyourservice")
                .then()
                .statusCode(200)
                .extract()
                .as(Item[].class);
        assertThat(result.length, equalTo(0));

        Map<String, Object> specAsMap = new HashMap<>();
        specAsMap.put("name", "anItem");
        specAsMap.put("description", "A sample item");

        given().contentType(ContentType.JSON).body(specAsMap)
                .when()
                .post("/doyourservice")
                .then()
                .statusCode(200).body(is("Executing anItem: A sample item"));

        result = given()
                .when().accept(ContentType.JSON).
                        get("/doyourservice")
                .then()
                .statusCode(200)
                .extract()
                .as(Item[].class);
        assertThat(result.length, equalTo(1));
    }
}