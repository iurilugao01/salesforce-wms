import { LightningElement, api } from 'lwc';
import lotesAVencer from '@salesforce/apex/WmsController.lotesAVencer';

const COLUNAS = [
    { label: 'Lote', fieldName: 'numeroLote' },
    { label: 'Produto', fieldName: 'produto' },
    { label: 'Validade', fieldName: 'validade', type: 'date-local' },
    { label: 'Dias restantes', fieldName: 'diasRestantes', type: 'number' },
    { label: 'Saldo total', fieldName: 'saldoTotal', type: 'number' }
];

export default class AlertaValidade extends LightningElement {
    @api dias = 30;
    colunas = COLUNAS;
    lotes = [];
    carregado = false;
    erro;

    get semLotes() {
        return this.carregado && this.lotes.length === 0;
    }

    async connectedCallback() {
        try {
            this.lotes = await lotesAVencer({ dias: Number(this.dias) });
        } catch (e) {
            this.erro = (e && e.body && e.body.message) || (e && e.message) || 'Erro inesperado.';
        } finally {
            this.carregado = true;
        }
    }
}
