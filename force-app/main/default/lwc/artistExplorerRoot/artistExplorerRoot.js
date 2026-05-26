import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getArtists from '@salesforce/apex/MongoArtistService.getArtists';
import importArtistsToSalesforce from '@salesforce/apex/MongoArtistService.importArtistsToSalesforce';

export default class ArtistExplorerRoot extends NavigationMixin(LightningElement) {
    artists = [];
    selectedArtistsByCode = {};
    importSummary;
    currentPage = 1;
    totalPages = 1;
    totalRecords = 0;
    hasNextPage = false;
    hasPreviousPage = false;
    isLoading = false;
    isImporting = false;
    errorMessage;

    connectedCallback() {
        this.loadArtists();
    }

    get hasRecords() {
        return this.artists.length > 0;
    }

    get displayedArtists() {
        return this.artists.map((artist) => ({
            ...artist,
            isSelected: Boolean(this.selectedArtistsByCode[artist.artist_code])
        }));
    }

    get selectedCount() {
        return Object.keys(this.selectedArtistsByCode).length;
    }

    get selectedArtists() {
        return Object.values(this.selectedArtistsByCode);
    }

    get hasSelection() {
        return this.selectedCount > 0;
    }

    get selectedSummaryLabel() {
        return `${this.selectedCount} selected across pages`;
    }

    get isBusy() {
        return this.isLoading || this.isImporting;
    }

    get disablePrevious() {
        return this.isBusy || !this.hasPreviousPage;
    }

    get disableNext() {
        return this.isBusy || !this.hasNextPage;
    }

    get disableImportSelected() {
        return this.isBusy || !this.hasSelection;
    }

    get showImportSummary() {
        return Boolean(this.importSummary);
    }

    get importedArtists() {
        return this.importSummary?.importedArtists ?? [];
    }

    get failedArtists() {
        return this.importSummary?.failedArtists ?? [];
    }

    get hasImportedArtists() {
        return this.importedArtists.length > 0;
    }

    get hasFailedArtists() {
        return this.failedArtists.length > 0;
    }

    async loadArtists() {
        this.isLoading = true;
        this.errorMessage = undefined;

        try {
            const response = await getArtists({ pageNumber: this.currentPage });
            this.artists = response?.data ?? [];
            this.currentPage = response?.currentPage ?? this.currentPage;
            this.totalPages = response?.totalPages ?? 1;
            this.totalRecords = response?.totalRecords ?? this.artists.length;
            this.hasNextPage = Boolean(response?.hasNextPage);
            this.hasPreviousPage = Boolean(response?.hasPreviousPage);
        } catch (error) {
            this.artists = [];
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.loadArtists();
    }

    handlePrevious() {
        if (this.hasPreviousPage && !this.isBusy) {
            this.currentPage -= 1;
            this.loadArtists();
        }
    }

    handleNext() {
        if (this.hasNextPage && !this.isBusy) {
            this.currentPage += 1;
            this.loadArtists();
        }
    }

    handleSelectionChange(event) {
        const artist = event.detail;
        const nextSelection = { ...this.selectedArtistsByCode };

        if (artist.selected) {
            nextSelection[artist.artist.artist_code] = this.toArtistDto(artist.artist);
        } else {
            delete nextSelection[artist.artist.artist_code];
        }

        this.selectedArtistsByCode = nextSelection;
    }

    handleClearSelection() {
        this.selectedArtistsByCode = {};
    }

    async handleImportSelected() {
        await this.importArtists(this.selectedArtists);
    }

    async importArtists(artists) {
        if (!artists?.length) {
            return;
        }

        this.isImporting = true;

        try {
            const artistsJson = JSON.stringify(artists.map((artist) => this.toArtistDto(artist)));
            const result = await importArtistsToSalesforce({
                artistsJson,
                artists: null
            });
            this.importSummary = await this.buildImportSummary(result);
            this.selectedArtistsByCode = {};
            this.showToast(
                this.importSummary.failedArtists.length ? 'Import finished with errors' : 'Import complete',
                this.importSummary.message,
                this.importSummary.failedArtists.length ? 'warning' : 'success'
            );
        } catch (error) {
            this.showToast('Import failed', this.reduceError(error), 'error');
        } finally {
            this.isImporting = false;
        }
    }

    toArtistDto(artist) {
        return {
            artist_code: artist.artist_code,
            full_name: artist.full_name,
            email_address: artist.email_address,
            tier_level: artist.tier_level,
            sales_amount: artist.sales_amount,
            artworks_sold: artist.artworks_sold,
            rising_star: artist.rising_star,
            country: artist.country,
            portfolio_score: artist.portfolio_score,
            available_for_exhibitions: artist.available_for_exhibitions
        };
    }

    async buildImportSummary(result) {
        const importedArtists = await Promise.all(
            (result?.importedArtists ?? []).map(async (artist) => {
                const fallbackUrl = `/lightning/r/Artist__c/${artist.salesforceRecordId}/view`;
                let recordUrl = fallbackUrl;

                try {
                    recordUrl = await this[NavigationMixin.GenerateUrl]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: artist.salesforceRecordId,
                            objectApiName: 'Artist__c',
                            actionName: 'view'
                        }
                    });
                } catch (error) {
                    recordUrl = fallbackUrl;
                }

                return {
                    ...artist,
                    recordUrl
                };
            })
        );

        return {
            importedCount: result?.importedCount ?? importedArtists.length,
            message: result?.message ?? 'Artists imported successfully',
            importedArtists,
            failedArtists: result?.failedArtists ?? []
        };
    }

    closeImportSummary() {
        this.importSummary = undefined;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    reduceError(error) {
        let message;

        if (Array.isArray(error?.body)) {
            message = error.body.map((item) => item.message).join(', ');
        } else if (Array.isArray(error?.body?.pageErrors)) {
            message = error.body.pageErrors.map((item) => item.message).join(', ');
        } else if (Array.isArray(error?.body?.output?.errors)) {
            message = error.body.output.errors.map((item) => item.message).join(', ');
        } else if (error?.body?.output?.fieldErrors) {
            message = Object.values(error.body.output.fieldErrors)
                .flat()
                .map((item) => item.message)
                .join(', ');
        } else {
            message =
                error?.body?.message ||
                error?.message ||
                error?.statusText ||
                JSON.stringify(error) ||
                'Something went wrong.';
        }

        const normalizedMessage = message.toLowerCase();

        if (
            normalizedMessage.includes('<!doctype html') ||
            normalizedMessage.includes('<html') ||
            normalizedMessage.includes('&lt;!doctype html') ||
            normalizedMessage.includes('&lt;html')
        ) {
            return 'Error while fetching artists. Mongo API returned an internal server error.';
        }

        return message;
    }
}
