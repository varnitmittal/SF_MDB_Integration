@IsTest
private class MongoArtistServiceTest {

    /*
    ============================================
    TEST GET ARTISTS SUCCESS
    ============================================
    */

    @IsTest
    static void testGetArtistsSuccess() {

        Test.setMock(
            HttpCalloutMock.class,
            new MongoArtistSuccessMock()
        );

        Test.startTest();

        MongoArtistService.ArtistResponse response =
            MongoArtistService.getArtists(1);

        Test.stopTest();

        System.assertNotEquals(
            null,
            response
        );

        System.assertEquals(
            1,
            response.currentPage
        );

        System.assertEquals(
            15,
            response.totalPages
        );

        System.assertEquals(
            10,
            response.limitCount
        );

        System.assertEquals(
            1,
            response.data.size()
        );

        System.assertEquals(
            'Nina Reynolds',
            response.data[0].full_name
        );

    }

    /*
    ============================================
    TEST GET ARTISTS FAILURE
    ============================================
    */

    @IsTest
    static void testGetArtistsFailure() {

        Test.setMock(
            HttpCalloutMock.class,
            new MongoArtistFailureMock()
        );

        Test.startTest();

        Boolean exceptionThrown = false;
        try {

            MongoArtistService.getArtists(1);

        } catch (AuraHandledException ex) {

            exceptionThrown = true;

        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Expected AuraHandledException to be thrown'
        );

    }

    /*
    ============================================
    TEST GET ARTISTS HTML SERVER ERROR
    ============================================
    */

    @IsTest
    static void testGetArtistsHtmlServerError() {

        HttpResponse res =
            new HttpResponse();

        res.setHeader(
            'Content-Type',
            'text/html'
        );

        res.setStatusCode(500);

        res.setBody(
            '<!DOCTYPE html><html><body><pre>Internal Server Error</pre></body></html>'
        );

        String exceptionMessage =
            MongoArtistService.buildCalloutErrorMessage(res);

        System.assert(
            exceptionMessage.contains(
                'Mongo API returned HTTP 500'
            ),
            'Exception message should include HTTP 500'
        );

        System.assertEquals(
            false,
            exceptionMessage.contains('<!DOCTYPE html>'),
            'Exception message should not expose raw HTML'
        );

    }

    /*
    ============================================
    TEST IMPORT TO SALESFORCE
    ============================================
    */

    @IsTest
    static void testImportArtistsToSalesforce() {

        List<MongoArtistService.ArtistDTO>
            artists =
            new List<MongoArtistService.ArtistDTO>();

        MongoArtistService.ArtistDTO dto =
            new MongoArtistService.ArtistDTO();

        dto.artist_code =
            'ART1001';

        dto.full_name =
            'Nina Reynolds';

        dto.email_address =
            'nina@test.com';

        dto.tier_level =
            'Gold';

        dto.rising_star =
            true;

        dto.sales_amount =
            50000;

        dto.artworks_sold =
            10;

        dto.country =
            'Germany';

        dto.portfolio_score =
            95;

        dto.available_for_exhibitions =
            true;

        artists.add(dto);

        Test.startTest();

        MongoArtistService.ImportResult result =
            MongoArtistService.importArtistsToSalesforce(
                JSON.serialize(artists),
                null
            );

        Test.stopTest();

        List<Artist__c> insertedArtists =
            [
                SELECT Id,
                       Name__c,
                       Email__c,
                       Tier__c,
                       Rising_Star__c,
                       Total_Sales_Amount__c,
                       Total_Artworks_Sold__c
                FROM Artist__c
            ];

        System.assertEquals(
            1,
            insertedArtists.size()
        );

        System.assertEquals(
            'Nina Reynolds',
            insertedArtists[0].Name__c
        );

        System.assertEquals(
            'nina@test.com',
            insertedArtists[0].Email__c
        );

        System.assertEquals(
            'Gold',
            insertedArtists[0].Tier__c
        );

        System.assertEquals(
            true,
            insertedArtists[0].Rising_Star__c
        );

        System.assertEquals(
            1,
            result.importedCount
        );

        System.assertEquals(
            '1 artists imported successfully',
            result.message
        );

        System.assertEquals(
            0,
            result.failedArtists.size()
        );

        System.assertEquals(
            1,
            result.importedArtists.size()
        );

        System.assertEquals(
            insertedArtists[0].Id,
            result.importedArtists[0].salesforceRecordId
        );

        System.assertEquals(
            'ART1001',
            result.importedArtists[0].artist_code
        );

    }

    /*
    ============================================
    TEST IMPORT SANITIZES MONGODB VALUES
    ============================================
    */

    @IsTest
    static void testImportArtistsSanitizesMongoValues() {

        MongoArtistService.ArtistDTO dto =
            new MongoArtistService.ArtistDTO();

        dto.artist_code =
            'ARTLONG';

        dto.full_name =
            'This Artist Name Is Intentionally Longer Than Fifty Characters';

        dto.email_address =
            'not-an-email';

        dto.tier_level =
            'diamond';

        dto.rising_star =
            null;

        dto.sales_amount =
            -10;

        dto.artworks_sold =
            -2;

        Test.startTest();

        MongoArtistService.ImportResult result =
            MongoArtistService.importArtistsToSalesforce(
                JSON.serialize(
                    new List<MongoArtistService.ArtistDTO>{
                        dto
                    }
                ),
                null
            );

        Test.stopTest();

        Artist__c insertedArtist =
            [
                SELECT Name__c,
                       Email__c,
                       Tier__c,
                       Rising_Star__c,
                       Total_Sales_Amount__c,
                       Total_Artworks_Sold__c
                FROM Artist__c
                WHERE Id = :result.importedArtists[0].salesforceRecordId
            ];

        System.assertEquals(
            1,
            result.importedCount
        );

        System.assertEquals(
            50,
            insertedArtist.Name__c.length()
        );

        System.assertEquals(
            null,
            insertedArtist.Email__c
        );

        System.assertEquals(
            null,
            insertedArtist.Tier__c
        );

        System.assertEquals(
            false,
            insertedArtist.Rising_Star__c
        );

        System.assertEquals(
            0,
            insertedArtist.Total_Sales_Amount__c
        );

        System.assertEquals(
            0,
            insertedArtist.Total_Artworks_Sold__c
        );

    }

    /*
    ============================================
    TEST IMPORT FAILS DUPLICATE EMAILS
    ============================================
    */

    @IsTest
    static void testImportArtistsFailsDuplicateEmails() {

        insert new Artist__c(
            Name__c = 'Existing Artist',
            Email__c = 'existing.artist@example.com',
            Tier__c = 'Gold',
            Rising_Star__c = false,
            Total_Sales_Amount__c = 100,
            Total_Artworks_Sold__c = 1
        );

        MongoArtistService.ArtistDTO dto =
            new MongoArtistService.ArtistDTO();

        dto.artist_code =
            'ARTDUP';

        dto.full_name =
            'Duplicate Artist';

        dto.email_address =
            'existing.artist@example.com';

        dto.tier_level =
            'Gold';

        dto.rising_star =
            true;

        dto.sales_amount =
            500;

        dto.artworks_sold =
            3;

        Test.startTest();

        MongoArtistService.ImportResult result =
            MongoArtistService.importArtistsToSalesforce(
                JSON.serialize(
                    new List<MongoArtistService.ArtistDTO>{
                        dto
                    }
                ),
                null
            );

        Test.stopTest();

        System.assertEquals(
            0,
            result.importedCount
        );

        System.assertEquals(
            0,
            result.importedArtists.size()
        );

        System.assertEquals(
            1,
            result.failedArtists.size()
        );

        System.assertEquals(
            'ARTDUP',
            result.failedArtists[0].artist_code
        );

        System.assertEquals(
            'An Artist with this email already exists in Salesforce.',
            result.failedArtists[0].errorMessage
        );

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Artist__c
                WHERE Email__c = 'existing.artist@example.com'
            ]
        );

    }

}
