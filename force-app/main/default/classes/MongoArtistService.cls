public with sharing class MongoArtistService {

    /*
    ============================================
    WRAPPER CLASSES
    ============================================
    */

    public class ArtistResponse {

        @AuraEnabled
        public Integer currentPage;

        @AuraEnabled
        public Integer limitCount;

        @AuraEnabled
        public Integer totalRecords;

        @AuraEnabled
        public Integer totalPages;

        @AuraEnabled
        public Boolean hasNextPage;

        @AuraEnabled
        public Boolean hasPreviousPage;

        @AuraEnabled
        public List<ArtistDTO> data;

    }

    public class ArtistDTO {

        @AuraEnabled
        public String artist_code;

        @AuraEnabled
        public String full_name;

        @AuraEnabled
        public String email_address;

        @AuraEnabled
        public String tier_level;

        @AuraEnabled
        public Decimal sales_amount;

        @AuraEnabled
        public Integer artworks_sold;

        @AuraEnabled
        public Boolean rising_star;

        @AuraEnabled
        public String country;

        @AuraEnabled
        public Integer portfolio_score;

        @AuraEnabled
        public Boolean available_for_exhibitions;

    }

    public class ImportResult {

        @AuraEnabled
        public Integer importedCount;

        @AuraEnabled
        public String message;

        @AuraEnabled
        public List<ImportedArtist> importedArtists;

        @AuraEnabled
        public List<ImportFailure> failedArtists;

    }

    public class ImportedArtist {

        @AuraEnabled
        public String artist_code;

        @AuraEnabled
        public String full_name;

        @AuraEnabled
        public String email_address;

        @AuraEnabled
        public Id salesforceRecordId;

    }

    public class ImportFailure {

        @AuraEnabled
        public String artist_code;

        @AuraEnabled
        public String full_name;

        @AuraEnabled
        public String email_address;

        @AuraEnabled
        public String errorMessage;

    }

    /*
    ============================================
    FETCH ARTISTS FROM MONGODB
    ============================================
    */

    @AuraEnabled(cacheable=true)
    public static ArtistResponse getArtists(
        Integer pageNumber
    ) {

        Integer requestedPage =
            pageNumber == null || pageNumber < 1
                ? 1
                : pageNumber;

        System.debug('=== MongoArtistService START ===');

        System.debug(
            'Requested Page Number: ' + requestedPage
        );

        HttpRequest req = new HttpRequest();

        String endpoint =
            'callout:MongoAPI/artists?page=' +
            requestedPage;

        System.debug('Endpoint: ' + endpoint);

        req.setEndpoint(endpoint);

        req.setMethod('GET');

        req.setHeader(
            'Accept',
            'application/json'
        );

        req.setTimeout(120000);

        Http http = new Http();

        System.debug('Sending HTTP request...');

        HttpResponse res = http.send(req);

        System.debug(
            'Response Status Code: ' +
            res.getStatusCode()
        );

        System.debug(
            'Response Body: ' +
            res.getBody()
        );

        if(res.getStatusCode() != 200) {

            System.debug(
                'ERROR OCCURRED WHILE FETCHING ARTISTS'
            );

            throw new AuraHandledException(
                buildCalloutErrorMessage(res)
            );

        }

        ArtistResponse responseObj =
            (ArtistResponse)
            JSON.deserialize(
                res.getBody(),
                ArtistResponse.class
            );

        System.debug(
            'Artists Retrieved: ' +
            (
                responseObj.data == null
                    ? 0
                    : responseObj.data.size()
            )
        );

        System.debug('=== MongoArtistService END ===');

        return responseObj;

    }

    @TestVisible
    private static String buildCalloutErrorMessage(
        HttpResponse res
    ) {

        String responseBody =
            res.getBody();

        if(String.isBlank(responseBody)) {

            return
                'Error while fetching artists. Mongo API returned HTTP ' +
                res.getStatusCode() +
                ' ' +
                res.getStatus();

        }

        String trimmedBody =
            responseBody.trim();

        if(
            trimmedBody.startsWith('{') ||
            trimmedBody.startsWith('[')
        ) {

            try {

                Object parsed =
                    JSON.deserializeUntyped(trimmedBody);

                if(parsed instanceof Map<String, Object>) {

                    Map<String, Object> parsedMap =
                        (Map<String, Object>) parsed;

                    if(parsedMap.containsKey('message')) {

                        return
                            'Error while fetching artists: ' +
                            String.valueOf(parsedMap.get('message'));

                    }

                    if(parsedMap.containsKey('error')) {

                        return
                            'Error while fetching artists: ' +
                            String.valueOf(parsedMap.get('error'));

                    }

                }

            } catch (Exception ex) {

                System.debug(
                    'Unable to parse error response body: ' +
                    ex.getMessage()
                );

            }

        }

        if(trimmedBody.startsWith('<')) {

            return
                'Error while fetching artists. Mongo API returned HTTP ' +
                res.getStatusCode() +
                '. Check the Mongo API server logs for the /artists endpoint.';

        }

        return
            'Error while fetching artists: ' +
            trimmedBody;

    }

    /*
    ============================================
    IMPORT MONGODB ARTISTS TO SALESFORCE
    ============================================
    */

    @AuraEnabled
    public static ImportResult importArtistsToSalesforce(
        String artistsJson,
        List<ArtistDTO> artists
    ) {

        List<ArtistDTO> artistsToImport =
            new List<ArtistDTO>();

        if(!String.isBlank(artistsJson)) {

            artistsToImport =
                (List<ArtistDTO>) JSON.deserialize(
                    artistsJson,
                    List<ArtistDTO>.class
                );

        } else if(artists != null) {

            artistsToImport =
                artists;

        }

        return importArtists(
            artistsToImport
        );

    }

    @TestVisible
    private static ImportResult importArtists(
        List<ArtistDTO> artists
    ) {

        System.debug(
            '=== IMPORT ARTISTS START ==='
        );

        List<Artist__c> artistsToInsert =
            new List<Artist__c>();

        if(artists == null) {

            artists =
                new List<ArtistDTO>();

        }

        Set<String> requestedEmails =
            new Set<String>();

        for(ArtistDTO dto : artists) {

            if(isValidEmail(dto.email_address)) {

                requestedEmails.add(
                    dto.email_address.trim().toLowerCase()
                );

            }

        }

        Set<String> existingEmails =
            getExistingArtistEmails(
                requestedEmails
            );

        for(ArtistDTO dto : artists) {

            String normalizedEmail =
                isValidEmail(dto.email_address)
                    ? dto.email_address.trim().toLowerCase()
                    : null;

            if(
                normalizedEmail != null &&
                existingEmails.contains(normalizedEmail)
            ) {

                artistsToInsert.add(null);
                continue;

            }

            Artist__c artistRec =
                new Artist__c();

            artistRec.Name__c =
                truncateText(
                    dto.full_name,
                    50
                );

            if(isValidEmail(dto.email_address)) {

                artistRec.Email__c =
                    dto.email_address;

            }

            artistRec.Tier__c =
                normalizeTier(
                    dto.tier_level
                );

            artistRec.Rising_Star__c =
                dto.rising_star == true;

            artistRec.Total_Sales_Amount__c =
                dto.sales_amount == null || dto.sales_amount < 0
                    ? 0
                    : dto.sales_amount;

            artistRec.Total_Artworks_Sold__c =
                dto.artworks_sold == null || dto.artworks_sold < 0
                    ? 0
                    : dto.artworks_sold;

            artistsToInsert.add(artistRec);

        }

        List<Artist__c> nonDuplicateArtistsToInsert =
            new List<Artist__c>();

        for(Artist__c artistRec : artistsToInsert) {

            if(artistRec != null) {

                nonDuplicateArtistsToInsert.add(artistRec);

            }

        }

        Database.SaveResult[] saveResults =
            Database.insert(
                nonDuplicateArtistsToInsert,
                false
            );

        System.debug(
            'Artists Imported: ' +
            saveResults.size()
        );

        System.debug(
            '=== IMPORT ARTISTS END ==='
        );

        ImportResult result =
            new ImportResult();

        result.importedArtists =
            new List<ImportedArtist>();

        result.failedArtists =
            new List<ImportFailure>();

        Integer saveResultIndex =
            0;

        for(Integer index = 0; index < artists.size(); index++) {

            ArtistDTO dto =
                artists[index];

            String normalizedEmail =
                isValidEmail(dto.email_address)
                    ? dto.email_address.trim().toLowerCase()
                    : null;

            if(
                normalizedEmail != null &&
                existingEmails.contains(normalizedEmail)
            ) {

                result.failedArtists.add(
                    buildFailure(
                        dto,
                        'An Artist with this email already exists in Salesforce.'
                    )
                );

                continue;

            }

            Database.SaveResult saveResult =
                saveResults[saveResultIndex];

            saveResultIndex++;

            if(saveResult.isSuccess()) {

                ImportedArtist importedArtist =
                    new ImportedArtist();

                importedArtist.artist_code =
                    dto.artist_code;

                importedArtist.full_name =
                    dto.full_name;

                importedArtist.email_address =
                    dto.email_address;

                importedArtist.salesforceRecordId =
                    saveResult.getId();

                result.importedArtists.add(importedArtist);

            } else {

                result.failedArtists.add(
                    buildFailure(
                        dto,
                        joinSaveErrors(saveResult.getErrors())
                    )
                );

            }

        }

        result.importedCount =
            result.importedArtists.size();

        result.message =
            result.importedArtists.size() +
            ' artists imported successfully';

        if(!result.failedArtists.isEmpty()) {

            result.message +=
                ', ' +
                result.failedArtists.size() +
                ' failed';

        }

        return result;

    }

    private static String joinSaveErrors(
        Database.Error[] errors
    ) {

        List<String> messages =
            new List<String>();

        for(Database.Error error : errors) {

            messages.add(
                error.getMessage()
            );

        }

        return String.join(
            messages,
            '; '
        );

    }

    private static Set<String> getExistingArtistEmails(
        Set<String> normalizedEmails
    ) {

        Set<String> existingEmails =
            new Set<String>();

        if(normalizedEmails.isEmpty()) {

            return existingEmails;

        }

        for(Artist__c artist : [
            SELECT Email__c
            FROM Artist__c
            WHERE Email__c IN :normalizedEmails
        ]) {

            if(isValidEmail(artist.Email__c)) {

                existingEmails.add(
                    artist.Email__c.trim().toLowerCase()
                );

            }

        }

        return existingEmails;

    }

    private static ImportFailure buildFailure(
        ArtistDTO dto,
        String errorMessage
    ) {

        ImportFailure failedArtist =
            new ImportFailure();

        failedArtist.artist_code =
            dto.artist_code;

        failedArtist.full_name =
            dto.full_name;

        failedArtist.email_address =
            dto.email_address;

        failedArtist.errorMessage =
            errorMessage;

        return failedArtist;

    }

    private static String truncateText(
        String value,
        Integer maxLength
    ) {

        if(String.isBlank(value)) {

            return null;

        }

        return value.length() > maxLength
            ? value.substring(0, maxLength)
            : value;

    }

    private static Boolean isValidEmail(
        String emailAddress
    ) {

        if(String.isBlank(emailAddress)) {

            return false;

        }

        Pattern emailPattern =
            Pattern.compile(
                '(?i)^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$'
            );

        return emailPattern
            .matcher(emailAddress)
            .matches();

    }

    private static String normalizeTier(
        String tierLevel
    ) {

        if(String.isBlank(tierLevel)) {

            return null;

        }

        Map<String, String> validTiersByLowerName =
            new Map<String, String>{
                'bronze' => 'Bronze',
                'silver' => 'Silver',
                'gold' => 'Gold',
                'platinum' => 'Platinum'
            };

        return validTiersByLowerName.get(
            tierLevel.trim().toLowerCase()
        );

    }

}
