import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import registrar from '@salesforce/apex/WmsController.registrarMovimentacao';
import lotesDisponiveis from '@salesforce/apex/WmsController.lotesDisponiveis';
import sugerirLote from '@salesforce/apex/FefoService.sugerirLote';

const TIPOS = [
    { label: 'Entrada', value: 'Entrada' },
    { label: 'Saída', value: 'Saida' },
    { label: 'Transferência', value: 'Transferencia' }
];

export default class RegistrarMovimentacao extends LightningElement {
    tipoOptions = TIPOS;
    tipo = 'Entrada';
    produtoId;
    origemId;
    destinoId;
    loteId;
    quantidade;
    loteOptions = [];
    sugestao;
    loteManual = false;
    erro;
    salvando = false;
    chaveForm = 0;
    requisicao = 0;

    get chaves() {
        return [this.chaveForm];
    }
    get ehEntrada() {
        return this.tipo === 'Entrada';
    }
    get mostraOrigem() {
        return this.tipo !== 'Entrada';
    }
    get mostraDestino() {
        return this.tipo !== 'Saida';
    }
    get loteFilter() {
        return { criteria: [{ fieldPath: 'Produto__c', operator: 'eq', value: this.produtoId }] };
    }
    get textoSugestao() {
        if (!this.sugestao) {
            return '';
        }
        const validade = this.sugestao.validade ? ` (validade ${this.sugestao.validade})` : '';
        return `Sugestão FEFO: lote ${this.sugestao.numeroLote}${validade} — saldo ${this.sugestao.saldo}`;
    }
    get formularioCompleto() {
        const posicoesOk =
            (!this.mostraOrigem || !!this.origemId) && (!this.mostraDestino || !!this.destinoId);
        return !!(this.produtoId && this.loteId && posicoesOk && Number(this.quantidade) > 0);
    }
    get desabilitaSalvar() {
        return this.salvando || !this.formularioCompleto;
    }

    handleTipo(event) {
        this.requisicao += 1;
        this.tipo = event.detail.value;
        this.produtoId = undefined;
        this.origemId = undefined;
        this.destinoId = undefined;
        this.loteId = undefined;
        this.loteManual = false;
        this.loteOptions = [];
        this.sugestao = undefined;
        this.erro = undefined;
        this.chaveForm += 1;
    }
    handleProduto(event) {
        this.produtoId = event.detail.recordId || undefined;
        this.loteId = undefined;
        this.loteManual = false;
        this.atualizarLotes();
    }
    handleOrigem(event) {
        this.origemId = event.detail.recordId || undefined;
        this.loteManual = false;
        this.atualizarLotes();
    }
    handleDestino(event) {
        this.destinoId = event.detail.recordId || undefined;
    }
    handleLotePicker(event) {
        this.loteId = event.detail.recordId || undefined;
    }
    handleLoteCombo(event) {
        this.loteId = event.detail.value;
        this.loteManual = true;
    }
    handleQuantidade(event) {
        this.quantidade = event.detail.value;
        this.atualizarLotes();
    }

    async atualizarLotes() {
        this.requisicao += 1;
        const requisicao = this.requisicao;
        this.sugestao = undefined;
        if (this.ehEntrada || !this.produtoId || !this.origemId) {
            this.loteOptions = [];
            return;
        }
        try {
            const [opcoes, sugestao] = await Promise.all([
                lotesDisponiveis({ produtoId: this.produtoId, posicaoId: this.origemId }),
                sugerirLote({
                    produtoId: this.produtoId,
                    posicaoId: this.origemId,
                    quantidade: Number(this.quantidade) || 0
                })
            ]);
            if (requisicao !== this.requisicao) {
                return;
            }
            this.loteOptions = opcoes.map((o) => ({ label: o.rotulo, value: o.loteId }));
            this.sugestao = sugestao || undefined;
            if (!this.loteManual) {
                this.loteId = sugestao ? sugestao.loteId : undefined;
            }
        } catch (e) {
            if (requisicao === this.requisicao) {
                this.erro = this.mensagem(e);
            }
        }
    }

    async handleSalvar() {
        this.erro = undefined;
        this.salvando = true;
        try {
            await registrar({
                tipo: this.tipo,
                loteId: this.loteId,
                origemId: this.mostraOrigem ? this.origemId : null,
                destinoId: this.mostraDestino ? this.destinoId : null,
                quantidade: Number(this.quantidade)
            });
            const rotulo = TIPOS.find((t) => t.value === this.tipo).label;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Movimentação registrada',
                    message: `${rotulo} registrada com sucesso.`,
                    variant: 'success'
                })
            );
            this.limpar();
        } catch (e) {
            this.erro = this.mensagem(e);
        } finally {
            this.salvando = false;
        }
    }

    limpar() {
        this.produtoId = undefined;
        this.origemId = undefined;
        this.destinoId = undefined;
        this.loteId = undefined;
        this.quantidade = undefined;
        this.loteOptions = [];
        this.sugestao = undefined;
        this.loteManual = false;
        this.chaveForm += 1;
    }

    mensagem(e) {
        return (e && e.body && e.body.message) || (e && e.message) || 'Erro inesperado.';
    }
}
