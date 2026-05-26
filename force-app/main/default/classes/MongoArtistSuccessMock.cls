@IsTest
global class MongoArtistSuccessMock
implements HttpCalloutMock {

    global HttpResponse respond(
        HttpRequest req
    ) {

        HttpResponse res =
            new HttpResponse();

        res.setHeader(
            'Content-Type',
            'application/json'
        );

        res.setStatusCode(200);

        res.setBody(
            '{"currentPage":1,"limitCount":10,"totalRecords":150,"totalPages":15,"hasNextPage":true,"hasPreviousPage":false,"data":[{"artist_code":"ART1001","full_name":"Nina Reynolds","email_address":"nina@test.com","tier_level":"Gold","sales_amount":50000,"artworks_sold":10,"rising_star":true,"country":"Germany","portfolio_score":95,"available_for_exhibitions":true}]}'
        );

        return res;

    }

}