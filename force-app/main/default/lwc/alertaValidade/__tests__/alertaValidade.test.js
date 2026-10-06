import { createElement } from 'lwc';
import AlertaValidade from 'c/alertaValidade';
import lotesAVencer from '@salesforce/apex/WmsController.lotesAVencer';

jest.mock('@salesforce/apex/WmsController.lotesAVencer', () => ({ default: jest.fn() }), { virtual: true });

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function criar(props = {}) {
    const el = createElement('c-alerta-validade', { is: AlertaValidade });
    Object.assign(el, props);
    document.body.appendChild(el);
    return el;
}

describe('c-alerta-validade', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('busca com 30 dias por padrão e exibe os lotes na tabela', async () => {
        lotesAVencer.mockResolvedValue([
            { loteId: 'l1', numeroLote: 'L-1', produto: 'Leite', validade: '2026-10-10', diasRestantes: 4, saldoTotal: 10 }
        ]);
        const el = criar();
        await flush();
        expect(lotesAVencer).toHaveBeenCalledWith({ dias: 30 });
        const tabela = el.shadowRoot.querySelector('lightning-datatable');
        expect(tabela.data).toHaveLength(1);
        expect(tabela.columns.map((c) => c.fieldName)).toEqual([
            'numeroLote', 'produto', 'validade', 'diasRestantes', 'saldoTotal'
        ]);
    });

    it('respeita a propriedade dias', async () => {
        lotesAVencer.mockResolvedValue([]);
        criar({ dias: 7 });
        await flush();
        expect(lotesAVencer).toHaveBeenCalledWith({ dias: 7 });
    });

    it('sem lotes mostra a mensagem de estado vazio e esconde a tabela', async () => {
        lotesAVencer.mockResolvedValue([]);
        const el = criar();
        await flush();
        expect(el.shadowRoot.querySelector('.mensagem-vazio')).not.toBeNull();
        expect(el.shadowRoot.querySelector('lightning-datatable')).toBeNull();
    });

    it('mostra o erro quando o Apex falha', async () => {
        lotesAVencer.mockRejectedValue({ body: { message: 'Sem acesso' } });
        const el = criar();
        await flush();
        expect(el.shadowRoot.querySelector('.mensagem-erro').textContent).toContain('Sem acesso');
    });
});
