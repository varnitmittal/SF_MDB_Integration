import { createElement } from '@lwc/engine-dom';
import ArtistExplorerRoot from 'c/artistExplorerRoot';
import getArtists from '@salesforce/apex/MongoArtistService.getArtists';
import importArtistsToSalesforce from '@salesforce/apex/MongoArtistService.importArtistsToSalesforce';

jest.mock(
    '@salesforce/apex/MongoArtistService.getArtists',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/MongoArtistService.importArtistsToSalesforce',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

const ARTIST_RESPONSE = {
    currentPage: 1,
    limitCount: 10,
    totalRecords: 1,
    totalPages: 1,
    hasNextPage: false,
    hasPreviousPage: false,
    data: [
        {
            artist_code: 'ART1001',
            full_name: 'Nina Reynolds',
            email_address: 'nina@test.com',
            tier_level: 'Gold',
            sales_amount: 50000,
            artworks_sold: 10,
            rising_star: true,
            country: 'Germany',
            portfolio_score: 95,
            available_for_exhibitions: true
        }
    ]
};

const IMPORT_RESPONSE = {
    importedCount: 1,
    message: '1 artists imported successfully',
    importedArtists: [
        {
            artist_code: 'ART1001',
            full_name: 'Nina Reynolds',
            email_address: 'nina@test.com',
            salesforceRecordId: 'a00gK0000012345QAA'
        }
    ]
};

const flushPromises = async () => {
    await Promise.resolve();
    await Promise.resolve();
};

describe('c-artist-explorer-root', () => {
    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }

        jest.clearAllMocks();
    });

    it('renders artists returned by MongoArtistService', async () => {
        getArtists.mockResolvedValue(ARTIST_RESPONSE);

        const element = createElement('c-artist-explorer-root', {
            is: ArtistExplorerRoot
        });

        document.body.appendChild(element);
        await flushPromises();

        const artistCards = element.shadowRoot.querySelectorAll('c-artist-explorer-card');
        expect(getArtists).toHaveBeenCalledWith({ pageNumber: 1 });
        expect(artistCards).toHaveLength(1);
        expect(artistCards[0].artist.full_name).toBe('Nina Reynolds');
    });

    it('imports artists selected across the table', async () => {
        getArtists.mockResolvedValue(ARTIST_RESPONSE);
        importArtistsToSalesforce.mockResolvedValue(IMPORT_RESPONSE);

        const element = createElement('c-artist-explorer-root', {
            is: ArtistExplorerRoot
        });

        document.body.appendChild(element);
        await flushPromises();

        const artistCard = element.shadowRoot.querySelector('c-artist-explorer-card');
        artistCard.dispatchEvent(
            new CustomEvent('selectionchange', {
                detail: {
                    artist: ARTIST_RESPONSE.data[0],
                    selected: true
                }
            })
        );

        const importButton = Array.from(element.shadowRoot.querySelectorAll('lightning-button')).find(
            (button) => button.label === 'Import Selected'
        );
        importButton.click();
        await flushPromises();

        expect(importArtistsToSalesforce).toHaveBeenCalledWith({
            artists: [ARTIST_RESPONSE.data[0]]
        });
        expect(element.shadowRoot.querySelector('.slds-modal')).not.toBeNull();
    });
});
