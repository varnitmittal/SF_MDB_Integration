import { api, LightningElement } from 'lwc';

export default class ArtistExplorerCard extends LightningElement {
    @api artist = {};
    @api isImporting = false;
    @api selected = false;

    get selectionLabel() {
        return `Select ${this.artist?.full_name ?? 'artist'}`;
    }

    handleSelectionChange(event) {
        this.dispatchEvent(
            new CustomEvent('selectionchange', {
                detail: {
                    artist: this.artist,
                    selected: event.target.checked
                }
            })
        );
    }
}