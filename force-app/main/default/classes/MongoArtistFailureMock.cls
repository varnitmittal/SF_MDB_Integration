@IsTest
global class MongoArtistFailureMock
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

        res.setStatusCode(401);

        res.setBody(
            '{"error":"Unauthorized"}'
        );

        return res;

    }

}