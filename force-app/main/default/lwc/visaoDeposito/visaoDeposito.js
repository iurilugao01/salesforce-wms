import { LightningElement } from 'lwc';
import listarDepositos from '@salesforce/apex/WmsController.listarDepositos';
import buscarHierarquia from '@salesforce/apex/WmsController.buscarHierarquia';

export default class VisaoDeposito extends LightningElement {
    depositoOptions = [];
    depositoId;
    zonas = [];
    carregado = false;
    erro;

    get semZonas() {
        return this.carregado && this.zonas.length === 0;
    }

    async connectedCallback() {
        try {
            const depositos = await listarDepositos();
            this.depositoOptions = depositos.map((d) => ({ label: d.nome, value: d.id }));
        } catch (e) {
            this.erro = this.mensagem(e);
        }
    }

    async handleDeposito(event) {
        this.depositoId = event.detail.value;
        this.erro = undefined;
        this.carregado = false;
        try {
            const visao = await buscarHierarquia({ depositoId: this.depositoId });
            this.zonas = visao.zonas.map((z) => ({
                ...z,
                corredores: z.corredores.map((c) => ({
                    ...c,
                    posicoes: c.posicoes.map((p) => ({
                        ...p,
                        rotuloOcupacao: p.capacidade
                            ? `${p.ocupado} / ${p.capacidade} (${p.percentual}%)`
                            : `${p.ocupado} (sem capacidade definida)`
                    }))
                }))
            }));
            this.carregado = true;
        } catch (e) {
            this.erro = this.mensagem(e);
        }
    }

    mensagem(e) {
        return (e && e.body && e.body.message) || (e && e.message) || 'Erro inesperado.';
    }
}
